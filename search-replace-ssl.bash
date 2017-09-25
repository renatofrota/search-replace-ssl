#!/bin/bash
# run like this:
# curl -sO https://raw.githubusercontent.com/renatofrota/search-replace-ssl/master/search-replace-ssl.bash && bash search-replace-ssl.bash
echo -e "\n\tsearch-replace-ssl - v0.0.2 - https://github.com/renatofrota/search-replace-ssl\n";
home=$(wp option get home --skip-plugins --skip-themes | cut -d / -f 3-);
echo "HOME: $home";
wp=$(echo $home | sed 's|^www\.||');
echo "DOMAIN: $wp";
[[ "$home" == "www."* ]] && prefix="www." || prefix="";
read -${BASH_VERSION+e}rp "Search-replace to https? (y/N) " -n 1 sr;
if [[ "$sr" =~ (1|y|Y|s|S) ]]; then
    wp db export ${HOME}/$(date +%F-%H-%M-%S)-$(echo ${wp} | cut -d / -f 1)-backup.sql;
    echo "Step 1 - Replacing http://(www.)${wp} -> https://${prefix}${wp}";
    wp search-replace --precise --recurse-objects --all-tables --regex "https?:\/\/(www\\.)?${wp}" "https://${prefix}${wp}" --skip-themes --skip-plugins | grep -w -v "0\|skipped";
    wp cache flush --skip-themes --skip-plugins;
    echo "Step 2 - Replacing http:\/\/(www.)${wp} -> https:\/\/${prefix}${wp}";
    wp search-replace --precise --recurse-objects --all-tables "https?:\/\/(www\\.)?${wp}" "https:\/\/${prefix}${wp}" --skip-themes --skip-plugins | grep -w -v "0\|skipped";
    wp cache flush --skip-themes --skip-plugins;
    echo "Step 3 - Replacing http%3A%2F%2F(www.)${wp} -> https%3A%2F%2F${prefix}${wp}";
    wp search-replace --precise --recurse-objects --all-tables "https?%3A%2F%2F(www\\.)?${wp}" "https%3A%2F%2F${prefix}${wp}" --skip-themes --skip-plugins | grep -w -v "0\|skipped";
    wp cache flush --skip-themes --skip-plugins;
fi
echo
read -${BASH_VERSION+e}rp "Add redirection rules to .htaccess? (y/N) " -n 1 htrules;
if [[ "$htrules" =~ (1|y|Y|s|S) ]]; then
    if [ "${wp}" != "${home}" ]; then
        wp1="www.";
        wp2="";
        wp3="add";
    else
        wp1="";
        wp2="www\.";
        wp3="remove";
    fi;
    wpe=$(echo $wp | sed 's|\.|\\.|g' | sed 's|^www\\.||');
    content="# BEGIN HTTPS
# force https:// (and ${wp3} www prefix) in a single redirection
# prevent 'chained redirects' reducing 'TTFB' and improving scores
RewriteCond %{HTTPS} !on
RewriteCond %{HTTP:X-Forwarded-Proto} !https
RewriteCond %{HTTP_HOST} ^(www\.)?${wpe}
RewriteRule ^(.*)$ https://${wp1}${wp}/\$1 [R=301,L]
# ${wp3} www prefix on requests that are sent over HTTPS protocol
RewriteCond %{HTTPS} on
RewriteCond %{HTTP_HOST} ^${wp2}${wpe}
RewriteRule ^(.*)$ https://${wp1}${wp}/\$1 [R=301,L]
# set HTTPS env var on forwarded requests (prevent redirection loop)
SetEnvIf X-Forwarded-Proto https HTTPS=on
# END HTTPS
";
    echo "$content" > .htaccess_enablingssl;
    cat .htaccess >> .htaccess_enablingssl;
    mv .htaccess_enablingssl .htaccess;
    echo -e "\nAdded to .htaccess:";
    echo "$content";
    echo
fi
killme() {
    [[ "$0" == "search-replace-ssl.bash" ]] && echo -n "Done! Self destroying... " && sleep 1 && rm -fv "$0" || echo "It's all done. Do not forget to remove this script.";
}
trap killme EXIT
