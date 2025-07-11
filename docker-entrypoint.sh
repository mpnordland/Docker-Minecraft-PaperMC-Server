#!/bin/sh

set -e

if [ "$(id -u)" -eq 0 ]; then
  DOCKER_USER='dockeruser'
  DOCKER_GROUP='dockergroup'

  if ! id "$DOCKER_USER" >/dev/null 2>&1; then
      echo "First start of the docker container, start initialization process."

      USER_ID=${PUID:-9001}
      GROUP_ID=${PGID:-9001}
      echo "Starting with $USER_ID:$GROUP_ID (UID:GID)"

      # Check if the desired GROUP_ID is already in use
      if getent group $GROUP_ID >/dev/null 2>&1; then
          EXISTING_GROUP=$(getent group $GROUP_ID | cut -d: -f1)
          echo "GID $GROUP_ID is already in use by group $EXISTING_GROUP. Using this group."
          DOCKER_GROUP=$EXISTING_GROUP
      else
          addgroup --gid $GROUP_ID $DOCKER_GROUP
          echo "Created group $DOCKER_GROUP with GID $GROUP_ID."
      fi

      # Check if the desired USER_ID is already in use
      if id -u $USER_ID >/dev/null 2>&1; then
          EXISTING_USER=$(getent passwd $USER_ID | cut -d: -f1)
          echo "UID $USER_ID is already in use by user $EXISTING_USER. Using this user."
          DOCKER_USER=$EXISTING_USER
      else
          # Create user with the specified UID and associated group
          adduser --shell /bin/sh --uid $USER_ID --ingroup $DOCKER_GROUP --disabled-password --gecos "" $DOCKER_USER
          echo "Created user $DOCKER_USER with UID $USER_ID."
      fi

      # Set ownership and permissions
      chown -vR $USER_ID:$GROUP_ID /opt/minecraft
      chmod -vR ug+rwx /opt/minecraft

      if [ "$SKIP_PERM_CHECK" != "true" ]; then
          echo "change ownership of /data to $USER_ID:$GROUP_ID"
          chown -vR $USER_ID:$GROUP_ID /data
      fi
  fi

  echo "running as uid $USER_ID:$GROUP_ID"
  JAVA_CMD="gosu $DOCKER_USER:$DOCKER_GROUP java"
else
  echo "running as uid $(id -u)"
  JAVA_CMD="java"
fi

# Add memory settings if MEMORYSIZE is provided
if [ -n "$MEMORYSIZE" ]; then
    JAVA_CMD="$JAVA_CMD -Xms$MEMORYSIZE -Xmx$MEMORYSIZE"
fi

# Add additional Java flags if provided
if [ -n "$JAVAFLAGS" ]; then
    JAVA_CMD="$JAVA_CMD $JAVAFLAGS"
fi

# Execute the final command
exec $JAVA_CMD -jar /opt/minecraft/paperspigot.jar $PAPERMC_FLAGS nogui
