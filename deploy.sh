#!/usr/bin/env bash

# bash friendly output for jq
JQ="jq --raw-output --exit-status"
TAG="latest"

configure_aws_cli() {
  echo "1. Configuring AWS ..."

  aws --version
  aws configure set default.region $AWS_DEFAULT_REGION
  aws configure set default.output json
  aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
  aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
}

prune_images() {
  echo "4. Prune untagged old docker images ..."
  
  for image_digest in $( \
    aws ecr list-images \
      --region $AWS_DEFAULT_REGION \
      --repository-name starlite/micro-2 \
      --filter "tagStatus=UNTAGGED" | jq ".imageIds[].imageDigest"); do
    
    echo "Deleting untagged image ${image_digest}"
    aws ecr batch-delete-image --region $AWS_DEFAULT_REGION --repository-name starlite/micro-2 --image-ids imageDigest="${image_digest}" 

  done
}

push_ecr_image() {
  echo "2. Pushinging docker image to AWS ..."

  eval $(aws ecr get-login --region $AWS_DEFAULT_REGION)
  docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/starlite/micro-2:$TAG
}

deploy_cluster() {
  echo "3. Deploying docker images into cluster ..."

  family="starlite-micro-2"

  make_task_def
  register_definition

  if [[ $(aws ecs update-service --cluster starlite-dev --service micro-2-service --task-definition $revision | $JQ '.service.taskDefinition') != $revision ]]; then
    echo "Error updating service."
    exit 1
  fi

  echo "Service update took long"
  return 1
}

make_task_def() {
  task_template='[
    {
      "name": "micro-2",
      "image": "%s.dkr.ecr.%s.amazonaws.com/starlite/micro-2:%s",
      "essential": true,
      "memory": 200,
      "cpu": 10,
      "portMappings": [
        {
          "containerPort": 9001,
          "hostPort": 0
        }
      ]
    }
  ]'

  task_def=$(printf "$task_template" $AWS_ACCOUNT_ID $AWS_DEFAULT_REGION $TAG)
}

register_definition() {
  if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family $family | $JQ '.taskDefinition.taskDefinitionArn'); then
    echo "Revision: $revision"
  else
    echo "Failed to register task definition"
    return 1
  fi
}

configure_aws_cli
push_ecr_image
deploy_cluster
prune_images
