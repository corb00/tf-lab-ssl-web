#!/bin/bash
#Required
domain=test.corbit.cc
echo "Generating SSL for $domain"
commonname=$domain
country=US
state=NY
locality=NewYork
organization=Test
organizationalunit=test
email=stefano.corbellini@gmail.com

echo "Generating key request for $domain"

mkdir -p /etc/ssl/private
chmod 700 /etc/ssl/private
cd /etc/ssl/private

#Create the request
echo "Creating CSR"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/$domain.key -out /etc/ssl/certs/$domain.crt \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"

echo "---------------------------"
echo "-----Below is your Certificate-----"
echo "---------------------------"
echo
cat /etc/ssl/certs/$domain.crt

echo
echo "---------------------------"
echo "-----Below is your Key-----"
echo "---------------------------"
echo
cat /etc/ssl/private/$domain.key

# enable in prod::
# openssl dhparam -out /etc/ssl/certs/dhparam.pem 2049

apt update
apt install -y nginx
ufw --force enable
ufw allow 'Nginx HTTPS'
systemctl stop nginx

cat <<EOF > /etc/nginx/conf.d/ssl.conf
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $domain;
    ssl_certificate /etc/ssl/certs/$domain.crt;
    ssl_certificate_key /etc/ssl/private/$domain.key;
    # ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_protocols TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_ecdh_curve secp384r1;
    ssl_session_timeout  10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    # Disable preloading HSTS for now.  You can use the commented out header line that includes
    # the "preload" directive if you understand the implications.
    #add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    root /usr/share/nginx/html;
    location / {
    }
    error_page 404 /404.html;
    location = /404.html {
    }
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
    }
}
EOF
systemctl start nginx
systemctl status nginx
systemctl enable nginx