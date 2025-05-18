# Development Environment Setup for Mundito Spanish

This document provides detailed instructions for setting up a development environment for the Mundito Spanish Laravel application, focusing on a WSL2/Windows hybrid setup.

## System Architecture

The recommended development environment uses a hybrid setup:

-   **WSL2 (Ubuntu)**: Runs Apache web server and PHP
-   **Windows**: Runs MySQL via WampServer
-   **VS Code**: Used with Remote-WSL extension for editing

This approach leverages the best of both environments: Linux for web serving and Windows for database management.

## Prerequisites

-   Windows 10 or 11 with WSL2 enabled
-   Ubuntu 20.04 or newer as your WSL2 distribution
-   WampServer installed on Windows (for MySQL)
-   Visual Studio Code with Remote-WSL extension
-   PHP 8.1 or higher
-   Composer
-   Node.js and npm

## Setup Instructions

### 1. WSL2 Configuration

1. **Install required packages**:

    ```bash
    sudo apt update
    sudo apt install apache2 php php-curl php-mbstring php-xml php-zip php-mysql unzip git
    ```

2. **Install Composer**:

    ```bash
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
    ```

3. **Install Node.js and npm** (using NVM for better version management):

    ```bash
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    source ~/.bashrc
    nvm install 18  # Or another LTS version
    ```

4. **Configure Apache to listen on port 8080**:

    ```bash
    sudo nano /etc/apache2/ports.conf
    # Add the line: Listen 8080
    sudo service apache2 restart
    ```

5. **Enable required Apache modules**:
    ```bash
    sudo a2enmod rewrite
    sudo service apache2 restart
    ```

### 2. Project Setup

1. **Clone the repository**:

    ```bash
    cd /var/www
    sudo git clone https://github.com/yourusername/mundito-spanish.git
    ```

2. **Set up file permissions**:

    ```bash
    # Replace 'yourusername' with your WSL username
    sudo chown -R yourusername:www-data /var/www/mundito-spanish
    sudo chmod -R g+w /var/www/mundito-spanish
    sudo find /var/www/mundito-spanish -type d -exec chmod g+s {} \;

    # Laravel-specific permissions
    sudo chmod -R 775 /var/www/mundito-spanish/storage
    sudo chmod -R 775 /var/www/mundito-spanish/bootstrap/cache
    ```

3. **Install dependencies**:

    ```bash
    cd /var/www/mundito-spanish
    composer install
    npm install
    ```

4. **Configure environment**:

    ```bash
    cp .env.example .env
    php artisan key:generate

    # Edit .env file to update database settings
    nano .env

    # DB_HOST should be your Windows IP
    # Use `ip route show | grep default | awk '{print $3}'` to find it
    ```

### 3. Apache Virtual Host Configuration

1. **Create a virtual host file**:

    ```bash
    sudo nano /etc/apache2/sites-available/mundito-spanish.conf
    ```

2. **Add the following configuration**:

    ```apache
    <VirtualHost *:8080>
        ServerAdmin webmaster@localhost
        ServerName mundito-spanish.local

        DocumentRoot /var/www/mundito-spanish/public

        <Directory /var/www/mundito-spanish/public>
            Options -Indexes +FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>

        ErrorLog ${APACHE_LOG_DIR}/munditospanish-error.log
        CustomLog ${APACHE_LOG_DIR}/munditospanish-access.log combined
    </VirtualHost>
    ```

3. **Enable the site**:
    ```bash
    sudo a2ensite mundito-spanish.conf
    sudo service apache2 reload
    ```

### 4. Windows Host Configuration

1. **Edit hosts file on Windows**:

    - Open Notepad as Administrator
    - Open `C:\Windows\System32\drivers\etc\hosts`
    - Add the line: `127.0.0.1 mundito-spanish.local`

2. **Start WampServer** and ensure MySQL service is running

3. **Create database and user**:
    - Open phpMyAdmin from WampServer menu
    - Create a new database named `mundito_spanish`
    - Create a user with appropriate permissions

### 5. Startup Script

For convenience, use the provided startup script:

1. **Make the script executable**:

    ```bash
    chmod +x /var/www/mundito-spanish/start.sh
    ```

2. **Run the script when starting development**:
    ```bash
    ./start.sh
    ```

## Building Frontend Assets

During development, you can use:

```bash
# For development (with HMR)
npm run dev

# For production build
npm run build
```

## Accessing the Site

Once everything is set up, you can access the site at:

```
http://mundito-spanish.local:8080
```

## React Integration

This project uses a hybrid approach with Blade templates, Alpine.js, and React components:

1. The React code is located in `resources/js/react/`
2. Add new components in `resources/js/react/components/`
3. Use React components in Blade templates with:

```blade
<x-react-component
   component="ComponentName"
   :props="['propName' => 'value']"
/>
```

## VS Code Integration

1. **Install VS Code Remote - WSL extension**

2. **Open the project in VS Code**:

    ```bash
    cd /var/www/mundito-spanish
    code .
    ```

3. **Recommended VS Code extensions**:
    - Laravel Blade Snippets
    - Laravel Snippets
    - PHP Intelephense
    - Tailwind CSS IntelliSense
    - ES7+ React/Redux/React-Native snippets

## Debugging

### Laravel Debugging

1. **Enable Laravel Telescope**:

    - Access `/telescope` route when in development environment

2. **Check Laravel logs**:
    ```bash
    tail -f /var/www/mundito-spanish/storage/logs/laravel.log
    ```

### Apache Debugging

```bash
sudo tail -f /var/log/apache2/munditospanish-error.log
```

### Database Debugging

Direct MySQL connection from WSL:

```bash
mysql -h [windows-ip] -u mundito_user -p
```

## Performance Optimization

-   Use Laravel artisan commands for cache optimization:

    ```bash
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    ```

-   For development, clear caches:
    ```bash
    php artisan optimize:clear
    ```

## Troubleshooting

### Permission Issues

If you encounter permission issues:

```bash
sudo chown -R yourusername:www-data /var/www/mundito-spanish
sudo chmod -R g+w /var/www/mundito-spanish
sudo find /var/www/mundito-spanish -type d -exec chmod g+s {} \;
sudo chmod -R 775 /var/www/mundito-spanish/storage
sudo chmod -R 775 /var/www/mundito-spanish/bootstrap/cache
```

### Database Connection Issues

If database connection fails:

1. Verify WampServer is running
2. Check the IP address in `.env`
3. Confirm MySQL user has proper permissions
4. Try connecting with MySQL client to test:
    ```bash
    mysql -h <windows-ip> -u <user> -p
    ```

### Apache Issues

If Apache doesn't start:

```bash
sudo service apache2 status
sudo tail -f /var/log/apache2/error.log
```

## Testing

Run Pest tests with:

```bash
php artisan test
```
