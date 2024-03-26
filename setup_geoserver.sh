#!/bin/bash

# Check if the script is running with root privileges
if [ "$EUID" -ne 0 ]
  then echo "Please run this script as root using sudo."
  exit
fi

# Update system packages
sudo apt-get update

# Install OpenJDK 11 JDK and JRE
sudo apt-get install -y openjdk-11-jdk openjdk-11-jre

# Display Java version
java -version

# Install gnupg2
sudo apt-get install -y gnupg2

# Add PostgreSQL repository key
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Add PostgreSQL repository to sources.list
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Update system packages again
sudo apt-get update

# Install PostGIS and PostgreSQL 13 with PostGIS extension
sudo apt-get install -y postgis postgresql-13-postgis-3 postgis

# Create GeoServer directory and download GeoServer
sudo mkdir -p /usr/share/geoserver
cd /usr/share/geoserver
sudo wget https://build.geoserver.org/geoserver/main/geoserver-main-latest-bin.zip
sudo apt-get install -y unzip
sudo unzip geoserver-main-latest-bin.zip
echo "export GEOSERVER_HOME=/usr/share/geoserver" >> ~/.profile
source ~/.profile

# Create geoserver system user
sudo useradd -m -U -s /bin/false geoserver
sudo chown -R geoserver:geoserver /usr/share/geoserver

# Create GeoServer systemd service file
sudo tee /usr/lib/systemd/system/geoserver.service > /dev/null <<EOL
[Unit]
Description=GeoServer Service
After=network.target

[Service]
Type=simple
User=geoserver
Group=geoserver
Environment="GEOSERVER_HOME=/usr/share/geoserver"
ExecStart=/usr/share/geoserver/bin/startup.sh
ExecStop=/usr/share/geoserver/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd
sudo systemctl daemon-reload

# Enable and start GeoServer service
sudo systemctl enable --now geoserver

# Check the status of GeoServer service
sudo systemctl status geoserver

# Print the GeoServer URL
echo "GeoServer is running at: http://your-server-ip:8080/geoserver"

# Create init.d script for GeoServer
sudo tee /etc/init.d/geoserver > /dev/null <<EOL
#!/bin/sh
### BEGIN INIT INFO
# Provides:          geoserver
# Required-Start:    \$local_fs \$remote_fs \$network \$syslog
# Required-Stop:     \$local_fs \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: GeoServer
# Description:       GeoServer daemon
### END INIT INFO

USER=geoserver
GEOSERVER_DATA_DIR=/usr/share/geoserver/data_dir
GEOSERVER_HOME=/usr/share/geoserver

PATH=/usr/sbin:/usr/bin:/sbin:/bin
DESC="GeoServer daemon"
NAME=geoserver
JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
JAVA_OPTS="-Xms128m -Xmx512m"

. /lib/lsb/init-functions

case "\$1" in
  start)
    echo "Starting \$DESC..."
    start-stop-daemon --start --chuid \$USER --make-pidfile --pidfile /var/run/\$NAME.pid --background --exec \$GEOSERVER_HOME/bin/startup.sh
    ;;
  stop)
    echo "Stopping \$DESC..."
    start-stop-daemon --stop --retry 10 --quiet --oknodo --pidfile /var/run/\$NAME.pid --exec \$GEOSERVER_HOME/bin/shutdown.sh
    ;;
  restart|force-reload)
    echo "Restarting \$DESC..."
    start-stop-daemon --stop --retry 10 --quiet --oknodo --pidfile /var/run/\$NAME.pid --exec \$GEOSERVER_HOME/bin/shutdown.sh
    sleep 1
    start-stop-daemon --start --chuid \$USER --make-pidfile --pidfile /var/run/\$NAME.pid --background --exec \$GEOSERVER_HOME/bin/startup.sh
    ;;
  *)
    echo "Usage: \$SCRIPTNAME {start|stop|restart|force-reload}" >&2
    exit 1
    ;;
esac

exit 0
EOL
# Make the init.d script executable
sudo chmod +x /etc/init.d/geoserver

# Start GeoServer using init.d
sudo /etc/init.d/geoserver start

# Print the GeoServer URL again
echo "GeoServer is running at: http://your-server-ip:8080/geoserver"
