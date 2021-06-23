DHPATH=/etc/dh/nginx.pem
if [ ! -e "$DHPATH" ] && [ "$SSL_TYPE" != "upstream" ]
then
  echo "diffie hellman private key does not exist; creating.."
  openssl dhparam -out "$DHPATH" 2048
fi

SELFSIGN_BASEPATH=/etc/selfsign/live/$DOMAIN
if [ "$SSL_TYPE" = "selfsign" ] && [ ! -e "$SELFSIGN_BASEPATH/privkey.pem" ]
then
  echo "self-signed cert requested but does not exist; creating.. (this could take a while)"
  mkdir -p $SELFSIGN_BASEPATH
  openssl req -x509 -newkey rsa:4086 \
    -subj "/C=XX/ST=XXXX/L=XXXX/O=XXXX/CN=localhost" \
    -keyout "$SELFSIGN_BASEPATH/privkey.pem" \
    -out "$SELFSIGN_BASEPATH/fullchain.pem" \
    -days 3650 -nodes -sha256
fi

echo "writing a new nginx configuration file.."
CNAME=$([ "$SSL_TYPE" = "customssl" ] && echo "local" || echo "$DOMAIN") \
/bin/bash -c "envsubst '\$SSL_TYPE \$CNAME' < /usr/share/nginx/odk.conf.template > /etc/nginx/conf.d/odk.conf"

if [ "$SSL_TYPE" = "letsencrypt" ]
then
  echo "starting nginx with certbot.."
  /bin/bash /scripts/entrypoint.sh
elif [ "$SSL_TYPE" = "upstream" ]
then
  perl -i -ne 's/listen 443.*/listen 80;/; print if ! /ssl_/' /etc/nginx/conf.d/odk.conf
  perl -i -pe 's/X-Forwarded-Proto \$scheme/X-Forwarded-Proto https/;' /etc/nginx/conf.d/odk.conf
  rm -f /etc/nginx/conf.d/certbot.conf
  echo "starting nginx without local SSL to allow for upstream SSL.."
  nginx -g "daemon off;"
else
  echo "starting nginx without certbot.."
  nginx -g "daemon off;"
fi

