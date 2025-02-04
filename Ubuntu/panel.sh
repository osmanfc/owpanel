#!/bin/sh

# Function to wait for the apt lock to be released
wait_for_apt_lock() {
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo "Waiting for apt lock to be released..."
        sleep 5
    done
}

# Function to generate a MariaDB-compatible random password
generate_mariadb_password() {
    # Generate a random password with 16 characters
    DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo "$DB_PASSWORD"
}


# Function to install Python and pip
install_pip() {
    echo "Updating system..."
    wait_for_apt_lock
    sudo apt update && sudo apt upgrade -y
    echo "Installing Python..."
    wait_for_apt_lock
    sudo apt install python3 -y
    echo "Installing pip..."
    wait_for_apt_lock
    sudo apt install python3-pip -y

    # Verify pip installation
    echo "Verifying pip installation..."
    pip3 --version

    echo "pip installation completed!"
	sudo apt install pkg-config libmysqlclient-dev -y
	pip install --upgrade pip setuptools
	pip install --no-binary :all: mysqlclient

# Upgrade pip and setuptools


# Install mysqlclient from source

}

# Function to install MySQL/MariaDB development libraries


# Function to install and configure MariaDB
install_mariadb() {
    local MYSQL_ROOT_PASSWORD="$1"

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        echo "Error: No password provided for root user. Skipping this task."
        return 1  # Skip task and continue with the script
    fi

    echo "Installing MariaDB server and client..."
    sudo sudo apt install -y mariadb-server mariadb-client

    if [ $? -ne 0 ]; then
        echo "Failed to install MariaDB. Skipping this task."
        return 1  # Skip task and continue with the script
    fi

    echo "Securing MariaDB installation..."
    sudo mysql_secure_installation <<EOF

Y
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
Y
Y
Y
Y
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to secure MariaDB installation. Skipping this task."
        return 1  # Skip task and continue with the script
    fi

    echo "MariaDB installation and root password configuration completed successfully."
}


change_mysql_root_password() {
    local NEW_PASSWORD="$1"

    if [ -z "$NEW_PASSWORD" ]; then
        echo "Usage: change_mysql_root_password <new_password>"
        return 1
    fi

    # Run the SQL command to change the root password
    OUTPUT=$(mysql -u root -e "
    ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_PASSWORD';
    FLUSH PRIVILEGES;" 2>&1)

    # Check for errors
    if echo "$OUTPUT" | grep -qE "ERROR|Access denied|authentication failure|wrong password"; then
        echo "Error: Failed to change the root password. Skipping to next task..."
        return 1  # Continue to the next task in a script
    fi

    echo "MariaDB root password changed successfully."
    return 0
}


create_database_and_user() {
    local ROOT_PASSWORD="$1"
    local DB_NAME="$2"
    local DB_USER="$3"

    # Check if all required arguments are provided
    if [ -z "$ROOT_PASSWORD" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
        echo "Usage: create_database_and_user <root_password> <database_name> <username>"
        return 1
    fi

    # Generate a random password for the new user
    local DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

    echo "Creating database and user..."

    # Execute the SQL commands to create the database and user
    mysql -u root -p"${ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    if [ $? -eq 0 ]; then
        echo "Database '${DB_NAME}' and user '${DB_USER}' created successfully."
        echo "Generated password for '${DB_USER}': ${DB_PASSWORD}"

        # Optionally save the credentials to a secure file
        echo "${DB_PASSWORD}" > /root/db_credentials_${DB_USER}.txt
        chmod 600 /root/db_credentials_${DB_USER}.txt
        echo "Credentials saved to /root/db_credentials_${DB_USER}.txt"
    else
        echo "Failed to create database or user. Please check the MariaDB server status and root password."
        return 1
    fi
}

get_password_from_file() {
    local password_file="$1"

    # Check if the file exists
    if [ ! -f "$password_file" ]; then
        echo "Error: File $password_file does not exist." >&2
        return 1
    fi

    # Read the password from the file
    local password
    password=$(cat "$password_file")

    # Check if the password is empty
    if [ -z "$password" ]; then
        echo "Error: File $password_file is empty." >&2
        return 1
    fi

    # Return the password
    echo "$password"
}

import_database() {
    local ROOT_PASSWORD="$1"
    local DB_NAME="$2"
    local DUMP_FILE="$3"

    # Check if all required arguments are provided
    if [ -z "$ROOT_PASSWORD" ] || [ -z "$DB_NAME" ] || [ -z "$DUMP_FILE" ]; then
        echo "Usage: import_database <root_password> <database_name> <dump_file>"
        return 1
    fi

    # Check if the dump file exists
    if [ ! -f "$DUMP_FILE" ]; then
        echo "Error: Dump file '$DUMP_FILE' does not exist."
        return 1
    fi

    echo "Importing database from '$DUMP_FILE' into '$DB_NAME'..."

    # Import the database
    mysql -u root -p"${ROOT_PASSWORD}" "$DB_NAME" < "$DUMP_FILE"

    if [ $? -eq 0 ]; then
        echo "Database imported successfully into '${DB_NAME}'."
    else
        echo "Failed to import the database. Please check the root password, database name, and dump file."
        return 1
    fi
}


install_mail_and_ftp_server() {
    # Configure Postfix to automatically choose 'Internet site' option during installation
    echo "postfix postfix/mailname string example.com" | sudo debconf-set-selections
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | sudo debconf-set-selections

    # Install Postfix, Dovecot, MariaDB, and Pure-FTPd
    echo "Installing Postfix, Dovecot, MariaDB, and Pure-FTPd..."

    # Update the package list
   

    # Install Postfix and related packages
    sudo apt-get install -y postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql

    # Check if Postfix and Dovecot installation is successful
    if [ $? -ne 0 ]; then
        echo "Failed to install Postfix, Dovecot, or MariaDB. Exiting."
        exit 1
    fi

    # Install Dovecot SQLite backend
    sudo apt-get install -y dovecot-sqlite dovecot-mysql

    # Check if Dovecot SQLite installation is successful
    if [ $? -ne 0 ]; then
        echo "Failed to install Dovecot SQLite backend. Exiting."
        exit 1
    fi

    # Install Pure-FTPd MySQL support
    sudo apt install -y pure-ftpd-mysql

    # Check if Pure-FTPd installation is successful
    if [ $? -ne 0 ]; then
        echo "Failed to install Pure-FTPd. Exiting."
        exit 1
    fi

    echo "Mail server and FTP server installation completed successfully!"
}

install_powerdns_and_mysql_backend() {
    # Install OpenSSL and PowerDNS with MySQL backend
    echo "Installing OpenSSL, PowerDNS, and PowerDNS MySQL backend..."

    # Install necessary packages
    
    sudo apt install -y openssl pdns-server pdns-backend-mysql

    if [ $? -ne 0 ]; then
        echo "Failed to install necessary packages. Exiting."
        exit 1
    fi

    # Configure permissions for pdns.conf
    echo "Configuring permissions for /etc/powerdns/pdns.conf..."

    # Set correct permissions for PowerDNS configuration file
    sudo chmod 644 /etc/powerdns/pdns.conf
    sudo chown pdns:pdns /etc/powerdns/pdns.conf

    if [ $? -eq 0 ]; then
        echo "Permissions set for /etc/powerdns/pdns.conf successfully."
    else
        echo "Failed to set permissions for /etc/powerdns/pdns.conf."
        exit 1
    fi

    echo "PowerDNS installation and configuration completed successfully!"
}

copy_files_and_replace_password() {
    local SOURCE_DIR="$1"
    local TARGET_DIR="$2"
    local NEW_PASSWORD="$3"

    # Check if all required arguments are provided
    if [ -z "$SOURCE_DIR" ] || [ -z "$TARGET_DIR" ] || [ -z "$NEW_PASSWORD" ]; then
        echo "Usage: copy_files_and_replace_password <source_directory> <target_directory> <new_password>"
        return 1
    fi

    # Ensure the source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Source directory '$SOURCE_DIR' does not exist. Exiting."
        return 1
    fi

    # Ensure the target directory exists, create it if it doesn't
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Target directory '$TARGET_DIR' does not exist. Creating it."
        mkdir -p "$TARGET_DIR"
    fi

    # Use rsync to copy the contents of the source directory to the target directory
    echo "Copying files from '$SOURCE_DIR' to '$TARGET_DIR'..."
    rsync -av --progress "$SOURCE_DIR/" "$TARGET_DIR/"

    if [ $? -eq 0 ]; then
        echo "Files copied successfully."

        # Replace '%password%' with the new password in all copied files
        echo "Replacing '%password%' with the new password in files..."
        find "$TARGET_DIR" -type f -exec sed -i "s/%password%/$NEW_PASSWORD/g" {} \;

        echo "Password replacement completed in files."
    else
        echo "Failed to copy files. Exiting."
        return 1
    fi
    # Create vmail group and user
    echo "Setting up 'vmail' group and user..."
    sudo groupadd -g 5000 vmail
    sudo useradd -g vmail -u 5000 vmail -d /var/mail

    # Create and set permissions for /var/mail/vhosts
    echo "Creating and setting permissions for '/var/mail/vhosts'..."
    sudo mkdir -p /var/mail/vhosts
    sudo chown -R vmail:vmail /var/mail/vhosts

    # Set ownership and permissions for Postfix configuration files
    sudo chown root:postfix /etc/postfix/mysql-virtual_domains.cf
    sudo chmod 640 /etc/postfix/mysql-virtual_domains.cf

    sudo chown root:postfix /etc/postfix/mysql-virtual_forwardings.cf
    sudo chmod 640 /etc/postfix/mysql-virtual_forwardings.cf

    sudo chown root:postfix /etc/postfix/mysql-virtual_mailboxes.cf
    sudo chmod 640 /etc/postfix/mysql-virtual_mailboxes.cf

    sudo chown root:postfix /etc/postfix/mysql-virtual_email2email.cf
    sudo chmod 640 /etc/postfix/mysql-virtual_email2email.cf

    sudo chown root:postfix /etc/postfix/mysql_transport.cf
    sudo chmod 640 /etc/postfix/mysql_transport.cf

    # Set ownership and correct permissions for Postfix main configuration files
    sudo chown root:postfix /etc/postfix/main.cf
    sudo chmod 644 /etc/postfix/main.cf

    sudo chown root:postfix /etc/postfix/master.cf
    sudo chmod 644 /etc/postfix/master.cf

    sudo chown root:postfix /etc/postfix/vmail_ssl.map
    sudo chmod 644 /etc/postfix/vmail_ssl.map

    # Set ownership and permissions for the vmail directory
    sudo chown -R vmail:vmail /home/vmail
    sudo chmod -R 700 /home/vmail

    # Set ownership to root and postfix
    sudo chown root:postfix /etc/letsencrypt/live/mail.chandpurtelecom.xyz/privkey.pem
    sudo chown root:postfix /etc/letsencrypt/live/mail.chandpurtelecom.xyz/fullchain.pem

    # Set permissions
    sudo chmod 640 /etc/letsencrypt/live/mail.chandpurtelecom.xyz/privkey.pem
    sudo chmod 644 /etc/letsencrypt/live/mail.chandpurtelecom.xyz/fullchain.pem
}

generate_pureftpd_ssl_certificate() {
    local CERT_PATH="/etc/ssl/private/pure-ftpd.pem"
    local SUBJECT="/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"
    local DAYS=3650

    echo "Checking if OpenSSL is installed..."

    # Check if OpenSSL is installed
    if ! command -v openssl &> /dev/null; then
        echo "OpenSSL is not installed. Installing it now..."
        sudo apt install -y openssl
        if [ $? -ne 0 ]; then
            echo "Failed to install OpenSSL. Exiting."
            return 1
        fi
    else
        echo "OpenSSL is already installed."
    fi

    echo "Generating a self-signed SSL certificate for Pure-FTPd..."

    # Ensure the target directory exists
    if [ ! -d "$(dirname "$CERT_PATH")" ]; then
        echo "Directory $(dirname "$CERT_PATH") does not exist. Creating it..."
        sudo mkdir -p "$(dirname "$CERT_PATH")"
    fi

    # Generate the certificate
    sudo openssl req -newkey rsa:1024 -new -nodes -x509 -days "$DAYS" -subj "$SUBJECT" -keyout "$CERT_PATH" -out "$CERT_PATH"

    if [ $? -eq 0 ]; then
        echo "SSL certificate generated successfully at $CERT_PATH."
        
        # Set proper permissions for the certificate
        sudo chmod 600 "$CERT_PATH"
        echo "Permissions for $CERT_PATH set to 600."
    else
        echo "Failed to generate the SSL certificate. Please check the OpenSSL configuration."
        return 1
    fi
}
# Function to suppress "need restart" prompts
suppress_restart_prompts() {
    echo "Suppressing 'need restart' prompts..."
    # Disable the "need restart" notifications
    sudo sed -i 's/#\$nrconf{restart} = '"'"'i'"'"';/\$nrconf{restart} = '"'"'a'"'"';/' /etc/needrestart/needrestart.conf
    # Automatically restart services without prompting
    sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/' /etc/needrestart/needrestart.conf
    echo "Restart prompts suppressed."
}

# Function to check if a reboot is required and reboot automatically
check_and_reboot() {
    if [ -f /var/run/reboot-required ]; then
        echo "A reboot is required to apply updates. Rebooting now..."
        sudo reboot
    else
        echo "No reboot required."
    fi
}


install_openlitespeed() {
    local NEW_ADMIN_USERNAME="admin"   # Default admin username
    local NEW_ADMIN_PASSWORD="$1" # Default admin password

   

    echo "Installing OpenLiteSpeed Web Server on Ubuntu..."

    # Update the package list
   

    # Download the OpenLiteSpeed repository setup script
    echo "Downloading OpenLiteSpeed repository setup script..."
    wget -O openlitespeed.sh https://repo.litespeed.sh

    # Run the script to add the OpenLiteSpeed repository
    echo "Running the repository setup script..."
    sudo bash openlitespeed.sh

    # Install OpenLiteSpeed
    echo "Installing OpenLiteSpeed..."
    sudo apt install openlitespeed -y

    # Verify installation
    if command -v lswsctrl &> /dev/null; then
        echo "OpenLiteSpeed installed successfully."

        # Start OpenLiteSpeed service
        echo "Starting OpenLiteSpeed service..."
        sudo /usr/local/lsws/bin/lswsctrl start
        sudo systemctl enable lsws

         
        # Display installed version
        echo "Checking OpenLiteSpeed version..."
        sudo /usr/local/lsws/bin/lshttpd -v
    else
        echo "OpenLiteSpeed installation failed. Please check for errors."
        return 1
    fi
}


change_ols_password() {
    # Check if a custom password is provided as an argument
    if [[ -z "$1" ]]; then
        echo "Error: No password provided."
        echo "Usage: Post_Install_Regenerate_Webadmin_Console_Passwd <your_custom_password>"
        return 1
    fi

    # Store the custom password
    Webadmin_Pass="$1"
    echo "Using custom web admin password: ${Webadmin_Pass}"

    # Check if the server edition is OpenLiteSpeed (OLS)
    
    PHP_Command="admin_php"
   

    # Encrypt the custom password using OpenLiteSpeed's htpasswd.php script
    Encrypt_string=$(/usr/local/lsws/admin/fcgi-bin/${PHP_Command} /usr/local/lsws/admin/misc/htpasswd.php "${Webadmin_Pass}")
    
    # Check if the encryption was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: Password encryption failed."
        return 1
    fi

    # Clear and update the htpasswd file with the new credentials
    echo "" > /usr/local/lsws/admin/conf/htpasswd
    echo "admin:$Encrypt_string" > /usr/local/lsws/admin/conf/htpasswd

    # Set the appropriate ownership and permissions for the htpasswd file
    chown lsadm:lsadm /usr/local/lsws/admin/conf/htpasswd
    chmod 600 /usr/local/lsws/admin/conf/htpasswd
    echo "Updated htpasswd file and set proper ownership/permissions."

    # Save the custom password to /etc/cyberpanel/webadmin_passwd
    echo "${Webadmin_Pass}" > /root/webadmin
    chmod 600 /root/webadmin
    echo "Saved the custom web admin password to /root/webadmin."

    return 0
}
copy_conf_for_ols() {
    # Define the source and target directories
    local SSL_SOURCE_DIR="/root/item/move/conf/ssl"
    local SSL_TARGET_DIR="/etc/letsencrypt/live/chandpurtelecom.xyz"
    local HTTPD_CONFIG_SOURCE="/root/item/move/conf/httpd_config.conf"
    local HTTPD_CONFIG_TARGET="/usr/local/lsws/conf/httpd_config.conf"

    # Ensure the source SSL directory exists
    if [ ! -d "$SSL_SOURCE_DIR" ]; then
        echo "Source SSL directory '$SSL_SOURCE_DIR' does not exist. Exiting."
        return 1
    fi

    # Ensure the target SSL directory exists, create it if it doesn't
    if [ ! -d "$SSL_TARGET_DIR" ]; then
        echo "Target SSL directory '$SSL_TARGET_DIR' does not exist. Creating it."
        mkdir -p "$SSL_TARGET_DIR"
    fi

    # Copy SSL files using rsync
    echo "Copying SSL files from '$SSL_SOURCE_DIR' to '$SSL_TARGET_DIR'..."
    rsync -av --progress "$SSL_SOURCE_DIR/" "$SSL_TARGET_DIR/"

    # Ensure the source httpd config file exists
    if [ ! -f "$HTTPD_CONFIG_SOURCE" ]; then
        echo "Source httpd config file '$HTTPD_CONFIG_SOURCE' does not exist. Exiting."
        return 1
    fi

    # Copy the httpd config file
    echo "Copying httpd config file '$HTTPD_CONFIG_SOURCE' to '$HTTPD_CONFIG_TARGET'..."
    cp -v "$HTTPD_CONFIG_SOURCE" "$HTTPD_CONFIG_TARGET"
	sudo systemctl restart openlitespeed

    echo "Copy operation completed."
}

allow_ports() {
    if [ $# -eq 0 ]; then
        echo "Error: No ports specified."
        return 1
    fi

    echo "Allowing specified ports through UFW and iptables..."

    # Allow each port through UFW and iptables
    for port in "$@"; do
        # UFW rule
        sudo ufw allow "$port/tcp"
        echo "Allowed $port/tcp through UFW."

        # iptables rule
        sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
        sudo iptables -A OUTPUT -p tcp --dport "$port" -j ACCEPT
        echo "Allowed $port/tcp through iptables."
    done

    # Special case for port range 40110-40210
    sudo ufw allow 40110:40210/tcp
    sudo iptables -A INPUT -p tcp --dport 40110:40210 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 40110:40210 -j ACCEPT
    echo "Allowed 40110:40210/tcp through both UFW and iptables."

    # Reload UFW to apply changes
    sudo ufw reload
    echo "UFW rules reloaded."

    return 0
}

install_zip_and_tar() {
    # Update package list
    echo "Updating package list..."
    

    # Install zip if not already installed
    if ! command -v zip &> /dev/null; then
        echo "Installing zip..."
        sudo apt install zip -y
    else
        echo "zip is already installed."
    fi

    # Install tar if not already installed
    if ! command -v tar &> /dev/null; then
        echo "Installing tar..."
        sudo apt install tar -y
    else
        echo "tar is already installed."
    fi

    echo "Installation of zip and tar completed."
}

install_acme_sh() {
    local email="$1"

    # Check if the email parameter is provided
    if [ -z "$email" ]; then
        echo "Usage: install_acme_sh <email>"
        return 1
    fi

    # Install acme.sh using the provided email
    echo "Installing acme.sh with email: $email..."
    wget -O -  https://get.acme.sh | sh -s email="$email"

    # Verify installation
    if [ $? -eq 0 ]; then
        echo "acme.sh installed successfully!"
    else
        echo "acme.sh installation failed."
        return 1
    fi
}


unzip_and_move() {

    sudo mkdir -p /root/item
    wget -O /root/item/install.zip "https://raw.githubusercontent.com/osmanfc/owpanel/main/item/install" 2>/dev/null
    unzip /root/item/install.zip -d /root/item/
    rm /root/item/install.zip
    wget -O /root/item/panel_setup.zip "https://owpanel.flexisoftwarebd.com/panel_setup.zip" 2>/dev/null
    local zip_file="/root/item/panel_setup.zip"
    local extract_dir="/root/item/cp"
    local target_dir="/usr/local/lsws/Example/html"

    # Ensure the zip file exists
    if [ ! -f "$zip_file" ]; then
        echo "Zip file '$zip_file' does not exist. Exiting."
        return 1
    fi

    # Ensure the target directory exists, create it if it doesn't
    if [ ! -d "$target_dir" ]; then
        echo "Target directory '$target_dir' does not exist. Creating it."
        mkdir -p "$target_dir"
    fi

    # Create the extraction directory if it doesn't exist
    if [ ! -d "$extract_dir" ]; then
        echo "Creating extraction directory: $extract_dir"
        mkdir -p "$extract_dir"
    fi

    # Unzip the file into the extraction directory
    echo "Unzipping '$zip_file' to '$extract_dir'..."
    unzip -o "$zip_file" -d "$extract_dir"
    if [ $? -ne 0 ]; then
        echo "Failed to unzip '$zip_file'. Exiting."
        return 1
    fi

    # Move all extracted files to the target directory
    echo "Moving contents of '$extract_dir' to '$target_dir'..."
    mv "$extract_dir"/* "$target_dir"

    echo "Unzipping and moving completed successfully."
}

setup_cp_service_with_port() {
    local service_file="/root/item/move/conf/cp.service"
    local target_dir="/etc/systemd/system/"
    local target_file="${target_dir}cp.service"
    local port_file="/root/item/port.txt"

    # Ensure the service file exists
    if [ ! -f "$service_file" ]; then
        echo "Service file '$service_file' does not exist. Exiting."
        return 1
    fi

    # Generate a random 4-digit port between 1000 and 9999
    local new_port=$(shuf -i 1000-9999 -n 1)

    # Save the new port to the port file
    echo "Saving the new port '$new_port' to '$port_file'..."
    echo "$new_port" > "$port_file"
    if [ $? -ne 0 ]; then
        echo "Failed to save the port to '$port_file'. Exiting."
        return 1
    fi

    # Replace the old port (8001) in the existing service file
    echo "Updating the port in '$service_file' to '$new_port'..."
    sed -i "s/8001/$new_port/g" "$service_file"
    if [ $? -ne 0 ]; then
        echo "Failed to update the port in the service file. Exiting."
        return 1
    fi

    # Copy the updated service file to the systemd directory
    echo "Copying the service file to '$target_dir'..."
    cp "$service_file" "$target_file"
    if [ $? -ne 0 ]; then
        echo "Failed to copy the service file. Exiting."
        return 1
    fi

    # Reload systemd daemon to recognize the updated service
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    # Start the service
    echo "Starting 'cp' service..."
    sudo systemctl start cp
    if [ $? -ne 0 ]; then
        echo "Failed to start 'cp' service. Exiting."
        return 1
    fi

    # Enable the service to start on boot
    echo "Enabling 'cp' service to start on boot..."
    sudo systemctl enable cp
    if [ $? -ne 0 ]; then
        echo "Failed to enable 'cp' service. Exiting."
        return 1
    fi
	
    allow_ports $new_port
    echo "'cp' service setup completed successfully with port '$new_port'."
}

copy_mysql_password() {
    local source_file="/root/item/mysqlPassword"
    local target_dir="/usr/local/lsws/Example/html/mypanel/etc/"
    local target_file="${target_dir}mysqlPassword"

    # Ensure the source file exists
    if [ ! -f "$source_file" ]; then
        echo "Source file '$source_file' does not exist. Exiting."
        return 1
    fi

    # Ensure the target directory exists, create it if it doesn't
    if [ ! -d "$target_dir" ]; then
        echo "Target directory '$target_dir' does not exist. Creating it."
        mkdir -p "$target_dir"
        if [ $? -ne 0 ]; then
            echo "Failed to create target directory '$target_dir'. Exiting."
            return 1
        fi
    fi

    # Copy the file to the target directory
    echo "Copying '$source_file' to '$target_file'..."
    cp "$source_file" "$target_file"
    if [ $? -ne 0 ]; then
        echo "Failed to copy '$source_file' to '$target_file'. Exiting."
        return 1
    fi
	sudo systemctl restart cp

    echo "File copied successfully from '$source_file' to '$target_file'."
}

set_ownership_and_permissions() {
    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/phpmyadmin 
    sudo chmod -R 755 /usr/local/lsws/Example/html/phpmyadmin 

    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/mypanel
    sudo chmod -R 755 /usr/local/lsws/Example/html/mypanel
    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/webmail
    sudo chmod -R 755 /usr/local/lsws/Example/html/webmail
	sudo chown -R nobody:nobody /usr/local/lsws/Example/html/webmail/data
	sudo chmod -R 755 /usr/local/lsws/Example/html/webmail/data


    echo "Ownership and permissions set successfully for all specified directories."
}

remove_files_in_html_folder() {
    target_dir="/usr/local/lsws/Example/html"
    files_to_remove="index.html phpinfo.php upload.html upload.php"

    # Check if the target directory exists
    if [ ! -d "$target_dir" ]; then
        echo "Directory '$target_dir' does not exist. Exiting."
        return 1
    fi

    # Loop through the files to remove and delete them
    for file in $files_to_remove; do
        file_path="$target_dir/$file"
        if [ -f "$file_path" ]; then
            echo "Removing file '$file_path'..."
            rm -f "$file_path"
            if [ $? -ne 0 ]; then
                echo "Failed to remove '$file_path'. Exiting."
                return 1
            fi
        else
            echo "File '$file_path' does not exist."
        fi
    done

    echo "Files removed successfully."
}

copy_vhconf_to_example() {
    local source_file="/root/item/move/conf/vhconf.conf"
    local target_dir="/usr/local/lsws/conf/vhosts/Example"
    local target_file="$target_dir/vhconf.conf"

    # Ensure the source file exists
    if [ ! -f "$source_file" ]; then
        echo "Source file '$source_file' does not exist. Exiting."
        return 1
    fi

    # Ensure the target directory exists
    if [ ! -d "$target_dir" ]; then
        echo "Target directory '$target_dir' does not exist. Creating it."
        mkdir -p "$target_dir"
        if [ $? -ne 0 ]; then
            echo "Failed to create target directory '$target_dir'. Exiting."
            return 1
        fi
    fi

    # Copy the source file to the target directory
    echo "Copying '$source_file' to '$target_file'..."
    cp "$source_file" "$target_file"
    if [ $? -ne 0 ]; then
        echo "Failed to copy the file. Exiting."
        return 1
    fi

    echo "File copied successfully to '$target_file'."
}

install_all_lsphp_versions() {
    echo "Installing OpenLiteSpeed PHP versions 7.4 to 8.4..."

    # Install software-properties-common if not installed
    sudo apt-get install -y software-properties-common

    # Add the OpenLiteSpeed PHP repository
    sudo add-apt-repository -y ppa:openlitespeed/php

    # Update package lists
    sudo apt-get update

    # Install PHP versions from 7.4 to 8.4
    for version in 74 80 81 82 83 84; do
        echo "Installing PHP $version..."
        sudo apt-get install -y lsphp"$version" lsphp"$version"-common lsphp"$version"-mysql

        # Check if installation was successful
        if [ -x "/usr/local/lsws/lsphp$version/bin/php" ]; then
            echo "PHP $version installed successfully!"
        else
            echo "PHP $version installation failed."
        fi
    done

    echo "All requested PHP versions installed."
}

create_dovecot_cert() {
    CERT_PATH="/etc/dovecot/cert.pem"
    KEY_PATH="/etc/dovecot/key.pem"

    echo "Creating SSL certificate for Dovecot..."

    # Generate a new self-signed SSL certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=localhost"

    # Set correct permissions
    chmod 600 "$KEY_PATH"
    chmod 644 "$CERT_PATH"
    chown root:root "$CERT_PATH" "$KEY_PATH"

    echo "SSL certificate created successfully at:"
    echo "  - Certificate: $CERT_PATH"
    echo "  - Private Key: $KEY_PATH"
}
create_vmail_user() {
    echo "Creating vmail user and group..."

    # Create the vmail group (if it doesn't exist)
    if ! grep -q "^vmail:" /etc/group; then
        sudo groupadd -g 5000 vmail
        echo "vmail group created."
    else
        echo "vmail group already exists."
    fi

    # Create the vmail user (if it doesn't exist)
    if ! id -u vmail &>/dev/null; then
        sudo useradd -g vmail -u 5000 -d /var/mail -s /sbin/nologin vmail
        echo "vmail user created."
    else
        echo "vmail user already exists."
    fi

    # Create the necessary directories for mail storage
    sudo mkdir -p /var/mail/vhosts
    sudo chown -R vmail:vmail /var/mail/vhosts
	sudo chmod -R 770 /var/mail

    echo "vmail user and directories setup complete."
}

fix_dovecot_log_permissions() {
    LOG_FILE="/home/vmail/dovecot-deliver.log"
    LOG_DIR="/home/vmail"
    USER="vmail"

    # Check if the log file exists
    if [ ! -f "$LOG_FILE" ]; then
        echo "Log file does not exist. Creating it..."
        touch "$LOG_FILE"
    fi

    # Set ownership to vmail user
    echo "Setting ownership for $LOG_FILE and $LOG_DIR to $USER..."
    chown -R $USER:$USER "$LOG_DIR"

    # Set appropriate permissions for the log file and directory
    echo "Setting permissions for $LOG_FILE..."
    chmod 644 "$LOG_FILE"
    chmod -R 700 "$LOG_DIR"

    # Restart Dovecot service to apply changes
    echo "Restarting Dovecot service..."
    systemctl restart dovecot

    # Check if SELinux exists before running getenforce
    if command -v getenforce &>/dev/null; then
        SELINUX_STATUS=$(getenforce)
        if [ "$SELINUX_STATUS" = "Enforcing" ]; then
            echo "SELinux is enabled. Checking for possible SELinux denials..."
            ausearch -m avc -ts recent
            echo "If SELinux is the cause, consider setting it to permissive temporarily: setenforce 0"
        fi
    else
        echo "SELinux is not installed or not available on this system."
    fi

    echo "Dovecot log permissions fixed successfully!"
}


display_success_message() {

    GREEN='\033[0;32m'
    NC='\033[0m'	
    # Get the IP address
    IP=$(hostname -I | awk '{print $1}')
    
    # Get the port from the file
    PORT=$(cat /root/item/port.txt)
	DB_PASSWORDx=$(get_password_from_file "/root/db_credentials_panel.txt")
    
    # Define the DB password (this can be dynamically set if needed)
   
    
    # Print success message in green
    echo "${GREEN}You have successfully installed the webhost panel!"
    echo "Admin URL is: https://${IP}:${PORT}"
    echo "Username: admin"
    echo "Password: ${DB_PASSWORDx}${NC}"
}
# Directory to save the password
PASSWORD_DIR="/root/item"
PASSWORD_FILE="$PASSWORD_DIR/mysqlPassword"

# Check if the directory exists, if not, create it
if [ ! -d "$PASSWORD_DIR" ]; then
    echo "Directory $PASSWORD_DIR does not exist. Creating it..."
    mkdir -p "$PASSWORD_DIR"
    if [ $? -ne 0 ]; then
        echo "Failed to create directory $PASSWORD_DIR. Exiting."
        exit 1
    fi
    echo "Directory $PASSWORD_DIR created successfully."
fi

# Generate a MariaDB-compatible random password
PASSWORD=$(generate_mariadb_password)  # Change 16 to your desired password length
echo "Generated MariaDB-Compatible Password: $PASSWORD"
DB_PASSWORD=$(get_password_from_file "/root/db_credentials_panel.txt")
# Save the password to the file
echo "$PASSWORD" > "$PASSWORD_FILE"
if [ $? -eq 0 ]; then
    echo "Password saved to $PASSWORD_FILE."
else
    echo "Failed to save password to $PASSWORD_FILE. Exiting."
    exit 1
fi

# Set appropriate permissions for the password file
chmod 600 "$PASSWORD_FILE"
if [ $? -eq 0 ]; then
    echo "Permissions set for $PASSWORD_FILE."
else
    echo "Failed to set permissions for $PASSWORD_FILE. Exiting."
    exit 1
fi

# Suppress "need restart" prompts
suppress_restart_prompts

# Install Python and pip if not already installed
install_pip

# Install and configure MariaDB
install_mariadb "$PASSWORD"

change_mysql_root_password "$PASSWORD"
create_database_and_user "$PASSWORD" "panel" "panel"
import_database "$PASSWORD" "panel" "/root/item/panel_db.sql"
install_openlitespeed "$DB_PASSWORD" 
change_ols_password "$DB_PASSWORD"
# Install Python dependencies from requirements.txt
echo "Installing Python dependencies from requirements.txt..."
if command -v pip3 &> /dev/null; then
    pip3 install -r requirements.txt
    if [ $? -eq 0 ]; then
        echo "Python dependencies installed successfully."
    else
        echo "Failed to install Python dependencies. Exiting."
        exit 1
    fi
else
    echo "pip3 is not installed. Exiting."
    exit 1
fi

# Check if a reboot is required and reboot automatically
#check_and_reboot

install_mail_and_ftp_server
install_powerdns_and_mysql_backend
copy_files_and_replace_password "/root/item/move/etc" "/etc" "$DB_PASSWORD"
generate_pureftpd_ssl_certificate
allow_ports 22 25 53 80 110 143 443 465 587 993 995 7080 3306 5353 6379 21 223 155 220 2205
copy_files_and_replace_password "/root/item/move/html" "/usr/local/lsws/Example/html" "$DB_PASSWORD"
install_zip_and_tar
install_acme_sh "my@example.com"
unzip_and_move
setup_cp_service_with_port
set_ownership_and_permissions
remove_files_in_html_folder
copy_vhconf_to_example
copy_mysql_password
install_all_lsphp_versions
create_dovecot_cert
create_vmail_user
fix_dovecot_log_permissions
copy_conf_for_ols
cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf
python3 /usr/local/lsws/Example/html/mypanel/manage.py reset_admin_password "${DB_PASSWORD:-112233}"
display_success_message
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
systemctl restart systemd-networkd >/dev/null 2>&1
sleep 3
sudo systemctl restart pdns
sudo systemctl restart postfix
sudo systemctl restart dovecot

