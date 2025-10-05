# Deployment Instructions:
# Use the automated deployment script for version control and deployment:
#   ./deploy.sh
#
# Or deploy manually:
#   aws ecr get-login-password --profile personal --region ap-southeast-1 | docker login --username AWS --password-stdin 885894375887.dkr.ecr.ap-southeast-1.amazonaws.com
#   docker build -t 885894375887.dkr.ecr.ap-southeast-1.amazonaws.com/telegram_toto_notification:v0.2.0 .
#   docker build -t 885894375887.dkr.ecr.ap-southeast-1.amazonaws.com/telegram_toto_notification:latest .
#   docker push 885894375887.dkr.ecr.ap-southeast-1.amazonaws.com/telegram_toto_notification:v0.2.0
#   docker push 885894375887.dkr.ecr.ap-southeast-1.amazonaws.com/telegram_toto_notification:latest

FROM umihico/aws-lambda-selenium-python:latest

RUN pip install python-telegram-bot==21.10

COPY main.py ./
CMD [ "main.handler" ]