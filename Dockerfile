FROM kristiandupont/dvdrental-image
RUN apt-get update && apt-get install -y postgresql-12-cron