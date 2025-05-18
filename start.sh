#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}=== Mundito-Spanish Startup Script ===${NC}"
echo "Starting services and configuring environment..."

if ! (grep -qE "(Microsoft|WSL)" /proc/version || grep -q "microsoft" /proc/sys/kernel/osrelease 2>/dev/null); then
    echo -e "${RED}Error: This script should be run in Windows Subsystem for Linux (WSL).${NC}"
    exit 1
fi

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    return 1
}

log_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

PROJECT_DIR="/var/www/mundito-spanish"
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "Project directory not found at $PROJECT_DIR"
    exit 1
fi
log_success "Project directory found"

if [ ! -f "$PROJECT_DIR/.env" ]; then
    log_error ".env file not found. Please create it from .env.example"
    exit 1
fi
log_success "Environment file exists"

WINDOWS_IP=$(ip route show | grep default | awk '{print $3}')
echo "Detected Windows host IP: $WINDOWS_IP"

DB_HOST=$(grep DB_HOST "$PROJECT_DIR/.env" | cut -d= -f2)
if [[ "$DB_HOST" != "$WINDOWS_IP" && "$DB_HOST" != "localhost" && "$DB_HOST" != "127.0.0.1" ]]; then
    read -p "Update database host to $WINDOWS_IP in .env file? (y/n): " update_host
    if [[ "$update_host" =~ ^[Yy]$ ]]; then
        sudo sed -i "s/DB_HOST=.*/DB_HOST=$WINDOWS_IP/" "$PROJECT_DIR/.env"
        log_success "Updated DB_HOST in .env to $WINDOWS_IP"
    else
        log_warning "Using existing DB_HOST=$DB_HOST"
    fi
fi

echo "Starting Apache web server..."
if ! sudo service apache2 status > /dev/null; then
    sudo service apache2 start
    if [ $? -ne 0 ]; then
        log_error "Failed to start Apache"
        exit 1
    fi
    log_success "Apache started"
else
    log_success "Apache already running"
fi

echo "Checking if Apache is listening on port 8080..."
if sudo ss -tulpn | grep -i apache | grep -q 8080; then
    log_success "Apache is listening on port 8080"
else
    log_warning "Apache may not be listening on port 8080"
    
    if ! grep -q "Listen 8080" /etc/apache2/ports.conf; then
        log_warning "Port 8080 not configured in ports.conf"
        echo "Would you like to update Apache to listen on port 8080? (y/n): "
        read update_port
        
        if [[ "$update_port" =~ ^[Yy]$ ]]; then
            echo "Listen 8080" | sudo tee -a /etc/apache2/ports.conf > /dev/null
            log_success "Updated ports.conf to listen on port 8080"
        fi
    fi
    
    sudo service apache2 restart
    
    if sudo ss -tulpn | grep -i apache | grep -q 8080; then
        log_success "Apache now listening on port 8080"
    else
        log_error "Apache still not listening on port 8080 after configuration"
        log_warning "Continuing startup process despite port check failure"
    fi
fi

VHOST_FILE="/etc/apache2/sites-available/mundito-spanish.conf"
if [ ! -f "$VHOST_FILE" ]; then
    log_error "Virtual host configuration file not found"
    exit 1
fi

if ! grep -q "mundito-spanish.local" "$VHOST_FILE"; then
    log_error "Virtual host not properly configured for mundito-spanish.local"
    exit 1
fi
log_success "Virtual host configuration found"

if [ ! -f "/etc/apache2/sites-enabled/mundito-spanish.conf" ]; then
    log_warning "Site is not enabled, enabling now..."
    sudo a2ensite mundito-spanish.conf
    sudo service apache2 reload
    log_success "Site enabled"
else
    log_success "Site already enabled"
fi

echo "Setting file permissions for development..."
CURRENT_USER=$(whoami)

sudo chown -R "$CURRENT_USER":www-data "$PROJECT_DIR"
sudo chmod -R g+w "$PROJECT_DIR"
sudo find "$PROJECT_DIR" -type d -exec chmod g+s {} \;

sudo chmod -R 775 "$PROJECT_DIR/storage"
sudo chmod -R 775 "$PROJECT_DIR/bootstrap/cache"
log_success "File permissions set for editing in VS Code and serving with Apache"

echo "Testing MySQL database connection..."
DB_NAME=$(grep DB_NAME "$PROJECT_DIR/.env" | cut -d= -f2)
DB_USER=$(grep DB_USER "$PROJECT_DIR/.env" | cut -d= -f2)
DB_PASS=$(grep DB_PASS "$PROJECT_DIR/.env" | cut -d= -f2)
DB_HOST=$(grep DB_HOST "$PROJECT_DIR/.env" | cut -d= -f2)

if command -v mysql &> /dev/null; then
    TIMEOUT_CMD="timeout 5"
    if $TIMEOUT_CMD mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "use $DB_NAME" &> /dev/null; then
        log_success "Successfully connected to MySQL database"
    else
        log_error "Could not connect to MySQL database. Please make sure WampServer is running"
        echo "Please start WampServer on your Windows host if not already running."
        echo "Continuing startup process despite database connection failure."
    fi
else
    log_warning "MySQL client not found. Cannot test database connection"
    echo "Install MySQL client with: sudo apt install mysql-client"
fi

if command -v powershell.exe &> /dev/null; then
    echo "Checking Windows hosts file..."
    HOST_ENTRY=$(powershell.exe -Command "Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String 'mundito-spanish.local'")
    
    if [ -z "$HOST_ENTRY" ]; then
        log_warning "Host entry for mundito-spanish.local not found in Windows hosts file"
        echo "Please add the following line to your Windows hosts file (as administrator):"
        echo "127.0.0.1 mundito-spanish.local"
    else
        log_success "Host entry found in Windows hosts file"
    fi
else
    log_warning "Could not check Windows hosts file. Please verify manually"
    echo "Ensure '127.0.0.1 mundito-spanish.local' exists in C:\Windows\System32\drivers\etc\hosts"
fi

echo "Checking Composer dependencies..."
cd "$PROJECT_DIR"

if [ ! -f "vendor/autoload.php" ]; then
    log_warning "Vendor directory not found. Running composer install..."
    composer install
    if [ $? -eq 0 ]; then
        log_success "Composer dependencies installed successfully"
    else
        log_error "Failed to install Composer dependencies"
        echo "Please run 'composer install' manually"
    fi
else
    log_success "Composer dependencies already installed"
fi

echo "Running Laravel maintenance commands..."

php artisan cache:clear
if [ $? -eq 0 ]; then log_success "Cache cleared"; else log_warning "Failed to clear cache"; fi

php artisan config:clear
if [ $? -eq 0 ]; then log_success "Config cache cleared"; else log_warning "Failed to clear config cache"; fi

php artisan view:clear
if [ $? -eq 0 ]; then log_success "View cache cleared"; else log_warning "Failed to clear view cache"; fi

php artisan optimize
if [ $? -eq 0 ]; then log_success "Laravel optimized"; else log_warning "Failed to optimize Laravel"; fi

WSL_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
echo -e "\n${GREEN}=== Startup Complete ===${NC}"
echo -e "Your Laravel application should be accessible at: ${GREEN}http://mundito-spanish.local:8080${NC}"
echo -e "If that doesn't work, try: ${GREEN}http://$WSL_IP:8080${NC}"
echo -e "Make sure WampServer is running on Windows for database access."

echo -e "\n${YELLOW}=== Additional Verification ===${NC}"
echo "1. Verify WampServer is running"
echo "2. Browser can access http://mundito-spanish.local:8080"
echo "3. Check Laravel logs if there are issues:"
echo "   tail -f $PROJECT_DIR/storage/logs/laravel.log"
echo "4. Check Apache logs if there are issues:"
echo "   sudo tail -f /var/log/apache2/munditospanish-error.log"
