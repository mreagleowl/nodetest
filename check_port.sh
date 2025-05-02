#!/bin/bash

read -rp "Enter port numbers separated by spaces (add +local for checking local docker ports): " -a INPUT

# Cheking for "+local" argument/key
SHOW_LOCAL=0
PORTS=()

for val in "${INPUT[@]}"; do
  if [ "$val" == "+local" ]; then
    SHOW_LOCAL=1
  else
    PORTS+=("$val")
  fi
done

if [ "${#PORTS[@]}" -eq 0 ]; then
  echo "Nothing to check ("
  exit 1
fi

for PORT in "${PORTS[@]}"; do
  echo -e "\n===== PORT $PORT ====="

  FOUND_DOCKER=0

  while IFS= read -r LINE; do
    ID=$(echo "$LINE" | awk '{print $1}')
    NAME=$(echo "$LINE" | awk '{print $2}')
    IMAGE=$(echo "$LINE" | awk '{print $3}')
    PORTS_LINE=$(echo "$LINE" | cut -d' ' -f4-)

    if [ "$SHOW_LOCAL" -eq 1 ]; then
      MATCH=$(echo "$PORTS_LINE" | grep -oE "([0-9\.:\[\]]+):$PORT->")
    else
      MATCH=$(echo "$PORTS_LINE" | grep -oE "(0\.0\.0\.0|\[::\]):$PORT->")
    fi

    if [ -n "$MATCH" ]; then
      echo "📦 Container : $NAME"
      echo "🖼️  Image     : $IMAGE"
      echo "🔁 NATed   : $PORTS_LINE"
      FOUND_DOCKER=1
    fi
  done < <(docker ps --format '{{.ID}} {{.Names}} {{.Image}} {{.Ports}}')

  sleep 0.2

  if [ "$FOUND_DOCKER" -eq 0 ]; then
    PROC_INFO=$(lsof -i :"$PORT" -sTCP:LISTEN -nP 2>/dev/null | awk 'NR==2 {print $1, $2}')
    if [ -n "$PROC_INFO" ]; then
      PROC_NAME=$(echo "$PROC_INFO" | awk '{print $1}')
      PROC_PID=$(echo "$PROC_INFO" | awk '{print $2}')
      echo "⚙️  Process   : $PROC_NAME (PID: $PROC_PID)"
      echo "⛔ Port $PORT is using by regular process."
    else
      echo "✅ Port $PORT si free."
    fi
  fi
done
