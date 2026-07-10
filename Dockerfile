# Thin wrapper over the official Mattermost Team Edition image.


# See https://hub.docker.com/r/mattermost/mattermost-team-edition/tags for latest version.
# Update task definition_container image in ecs.tf to match your version 
# Avoid using :latest version (floating/un-reproducible)
FROM mattermost/mattermost-team-edition:11.9.0
    
# Makes the non-root execution model explicit and auditable,
# rather than relying silently on the base image's default
USER 2000:2000

# Adds a container-level HEALTHCHECK for ECS task health monitoring
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8065/api/v4/system/ping || exit 1

LABEL org.opencontainers.image.source="https://github.com/ArisSaputraMd/aws-secure-infrastructure"