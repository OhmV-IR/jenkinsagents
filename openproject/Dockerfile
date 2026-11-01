# OpenProject with the patched EnterpriseToken model. The web, worker, cron and seeder services
# all run this one image, so one build covers every container that loads the Rails app.
# TAG matches the TAG the docker-compose config uses (default 17-slim).
ARG TAG=17-slim
FROM openproject/openproject:${TAG}

# WORKDIR of the upstream image is /app.
COPY --chown=app:app enterprise_token.rb /app/app/models/enterprise_token.rb
