FROM factoriotools/factorio:stable

# create /opt/factorio dir if it doesn't exist yet
RUN mkdir -p /factorio
# give factorio user (with uid 845) permissions to the /opt/factorio directory
RUN chown 845:845 /factorio

ENTRYPOINT ["/docker-entrypoint.sh"]
