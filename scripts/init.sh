######
#
# Description:
#   Init script to build and run the app in a docker container in your local environment
# Usage: 
#   ./init.sh ${APPNAME} ${CONTEXT}
#
######
APPNAME='ben-tech-challenge'
CONTEXT='/home/ec2-user/environment/ben-tech-challenge/app' # Must be full path (no aliases) to app directory
DOCKERFILE='../app/Dockerfile'
VERSION=$(git describe)
SHA=$(git rev-parse --short HEAD)
PORT=80
VERSION_TAG="$VERSION.$SHA"
IMAGE="$APPNAME-$VERSION_TAG"

# Check for input parameters
if [ -z "${1-}" ] || [ -z "${2-}" ]
then
  echo "APPNAME and CONTEXT not set on command line; Using default values ${APPNAME} ${CONTEXT}"
else
  APPNAME=$1
  CONTEXT=$2
fi

# Clean up container if it is already running
docker stop $APPNAME 2>/dev/null 
docker rm $APPNAME 2>/dev/null 

docker build --file $DOCKERFILE $CONTEXT --tag $IMAGE --build-arg APPNAME=$APPNAME --build-arg SHA=$SHA --build-arg VERSION=$VERSION --build-arg PORT=$PORT
docker run --detach --publish $PORT:$PORT --name $APPNAME --tty $IMAGE 