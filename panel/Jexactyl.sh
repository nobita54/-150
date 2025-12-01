# === Backup Phase (Panga-proof zone) ===
cp -R /var/www/pterodactyl /var/www/pterodactyl-backup
mysqldump -u root -p panel > /var/www/pterodactyl-backup/panel.sql

# === Update Phase ===
cd /var/www/pterodactyl
php artisan down

curl -L -o panel.tar.gz https://github.com/jexactyl/jexactyl/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz && rm -f panel.tar.gz

chmod -R 755 storage/* bootstrap/cache

# Composer install (speed + performance)
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

# === Laravel Maintenance ===
php artisan optimize:clear
php artisan migrate --seed --force

# Fix ownership (warna permissions maarenge)
chown -R www-data:www-data /var/www/pterodactyl/*

# Restart services & wake the beast
php artisan queue:restart
php artisan up

echo "-----------------------------"
echo "🎉 Panel Updated Successfully!"
echo "If kuch foot-paat ho jaye, backup ready hai."
echo "-----------------------------"

