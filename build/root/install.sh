#!/bin/bash

# exit script if return code != 0
set -e

# build scripts
####

# download build scripts from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/scripts-master.zip -L https://github.com/binhex/scripts/archive/master.zip

# unzip build scripts
unzip /tmp/scripts-master.zip -d /tmp

# move shell scripts to /root
mv /tmp/scripts-master/shell/arch/docker/*.sh /root/

# pacman packages
####

# define pacman packages
pacman_packages="git tk groovy jdk8-openjdk scala kotlin groovy"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed $pacman_packages --noconfirm
fi

# aor packages
####

# define arch official repo (aor) packages
aor_packages=""

# call aor script (arch official repo)
source /root/aor.sh

# aur packages
####

# define aur packages
aur_packages=""

# call aur install script (arch user repo)
source /root/aur.sh

cat <<'EOF' > /tmp/startcmd_heredoc
# check if recent projects directory config file exists, if it doesnt we assume
# intellij hasn't been run yet and thus set default location for future projects to
# external volume mapping.
if [ ! -f /config/intellij/config/options/recentProjects.xml ]; then
	mkdir -p /config/intellij/config/options
	cp /home/nobody/recentProjects.xml /config/intellij/config/options/recentProjects.xml
fi

# run intellij
/usr/bin/idea.sh
EOF

# replace startcmd placeholder string with contents of file (here doc)
sed -i '/# STARTCMD_PLACEHOLDER/{
    s/# STARTCMD_PLACEHOLDER//g
    r /tmp/startcmd_heredoc
}' /home/nobody/start.sh
rm /tmp/startcmd_heredoc

# config novnc
###

# overwrite novnc favicon with application favicon
cp /home/nobody/favicon.ico /usr/share/novnc/

# config openbox
####

cat <<'EOF' > /tmp/menu_heredoc
    <item label="IntelliJ">
    <action name="Execute">
      <command>/usr/bin/idea.sh</command>
      <startupnotify>
        <enabled>yes</enabled>
      </startupnotify>
    </action>
    </item>
EOF

# replace menu placeholder string with contents of file (here doc)
sed -i '/<!-- APPLICATIONS_PLACEHOLDER -->/{
    s/<!-- APPLICATIONS_PLACEHOLDER -->//g
    r /tmp/menu_heredoc
}' /home/nobody/.config/openbox/menu.xml
rm /tmp/menu_heredoc

# container perms
####

# create file with contets of here doc
cat <<'EOF' > /tmp/permissions_heredoc
if [ ! -d /opt/intellij/bin ]; then
    pkgver=2017.3.4
    _buildver=173.4548.28
    echo "[info] Installing Intellij Ultimate v$pkgver..." | ts '%Y-%m-%d %H:%M:%.S'
    curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/ideaIU-${pkgver}.tar.gz -L https://download.jetbrains.com/idea/ideaIU-${pkgver}.tar.gz
    tar xf /tmp/ideaIU-${pkgver}.tar.gz -C /tmp/
    mv /tmp/idea-IU-${_buildver}/* /opt/intellij/
    rm -rf /tmp/idea-IU-${_buildver}
    rm /tmp/ideaIU-${pkgver}.tar.gz

    echo "[info] Setting up Intellij installation..." | ts '%Y-%m-%d %H:%M:%.S'
    chown -R "${PUID}":"${PGID}" /opt/intellij
    chmod +x /opt/intellij/plugins/maven/lib/maven3/bin/mvn

    # set intellij path selector, this changes the path used by intellij to check for a custom idea.properties file
    # the path is constructed from /home/nobody/.<idea.paths.selector value>/config/ so the idea.properties file then needs
    # to be located in /home/nobody/.config/intellij/idea.properties, note double backslash to escape end backslash
    sed -i -e 's~-Didea.paths.selector=.*~-Didea.paths.selector=config/intellij \\~g' /opt/intellij/bin/idea.sh

    # set intellij paths for config, plugins, system and log, note the location of the idea.properties
    # file is constructed from the idea.paths.selector value, as shown above.
    mkdir -p /home/nobody/.config/intellij/config
    echo "idea.config.path=/config/intellij/config" > /home/nobody/.config/intellij/config/idea.properties
    echo "idea.plugins.path=/config/intellij/config/plugins" >> /home/nobody/.config/intellij/config/idea.properties
    echo "idea.system.path=/config/intellij/system" >> /home/nobody/.config/intellij/config/idea.properties
    echo "idea.log.path=/config/intellij/system/log" >> /home/nobody/.config/intellij/config/idea.properties
    chown -R "${PUID}":"${PGID}" /home/nobody/.config
fi

if [ ! -d /data/.nvm ]; then
    echo "[info] Installing nvm..." | ts '%Y-%m-%d %H:%M:%.S'
    mkdir -p /data/.nvm
    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | sh
    nvm install node
    chown -R "${PUID}":"${PGID}" /data/.nvm

    # set nvm in .bashrc
    touch /home/nobody/.bashrc
    echo "export NVM_DIR=\"/data/.nvm\"" > /home/nobody/.bashrc
    echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" > /home/nobody/.bashrc
    chown "${PUID}":"${PGID}" /home/nobody/.bashrc
fi

echo "[info] Setting permissions on files/folders inside container..." | ts '%Y-%m-%d %H:%M:%.S'

chown -R "${PUID}":"${PGID}" /tmp /usr/share/themes /home/nobody /usr/share/novnc /opt/intellij /usr/share/applications/ /etc/xdg
chmod -R 775 /tmp /usr/share/themes /home/nobody /usr/share/novnc /usr/share/applications/ /etc/xdg
ln -s /opt/intellij/bin/idea.sh /usr/bin/idea.sh

EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /root/init.sh
rm /tmp/permissions_heredoc

# env vars
####

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /usr/share/gtk-doc/*
rm -rf /tmp/*
