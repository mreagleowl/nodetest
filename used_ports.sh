#!/bin/bash

echo ""
echo "🔍 Поиск портов (без localhost)..."
echo ""

declare -A docker_ports_info
declare -A non_docker_ports_info

# --- Docker контейнеры ---
while IFS= read -r line; do
  container_id=$(echo "$line" | awk '{print $1}')
  image=$(echo "$line" | awk '{print $2}')
  name=$(echo "$line" | awk '{print $NF}')
  ports=$(echo "$line" | grep -oP '[0-9.:\[\]]+:[0-9]+->\d+/(tcp|udp)' || true)

  while IFS= read -r port_mapping; do
    host_ip_port=$(echo "$port_mapping" | cut -d'>' -f1)
    host_ip=$(echo "$host_ip_port" | cut -d':' -f1)
    host_port=$(echo "$port_mapping" | sed -E 's/.*:([0-9]+)->.*/\1/')
    proto=$(echo "$port_mapping" | grep -oE '(tcp|udp)' | tr '[:lower:]' '[:upper:]')

    if [[ "$host_ip" == "::1" ]]; then
      continue
    fi

    if [[ -n "$host_port" ]]; then
      key="$host_port|$proto"
      docker_ports_info["$key"]="$name|$image|$container_id"
    fi
  done <<< "$ports"

done < <(docker ps --format '{{.ID}} {{.Image}} {{.Ports}} {{.Names}}')

# --- Обычные приложения ---
while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $2}')
  proto=$(echo "$line" | awk '{print $8}' | tr '[:upper:]' '[:lower:]')
  port_field=$(echo "$line" | awk '{print $9}')
  ip=$(echo "$port_field" | sed -E 's/^(.*):([0-9]+)$/\1/')
  port=$(echo "$port_field" | sed -E 's/^(.*):([0-9]+)$/\2/')

  if [[ -n "${docker_ports_info["$port|${proto^^}"]}" ]]; then
    continue
  fi

  if [[ "$ip" == "::1" || "$ip" == "127.0.0.53" || "$ip" == "[::1]" ]]; then
    continue
  fi

  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    pname=$(ps -p "$pid" -o comm= 2>/dev/null)
  else
    pname="Неизвестный процесс"
  fi

  if [[ -n "$port" ]]; then
    key="$port|${proto^^}"
    non_docker_ports_info["$key"]="$port|${proto^^}|$pname|$pid"
  fi
done < <(sudo lsof -nP -i4 -sTCP:LISTEN -iUDP 2>/dev/null)

# --- Объединение и сортировка ---
all_ports=()
for p in "${!docker_ports_info[@]}"; do all_ports+=("$p"); done
for p in "${!non_docker_ports_info[@]}"; do all_ports+=("$p"); done
sorted_ports=($(printf "%s\n" "${all_ports[@]}" | sort -t'|' -k1,1n -k2 | uniq))

if [[ ${#sorted_ports[@]} -eq 0 ]]; then
  echo ""
  echo "Нет внешне проброшенных портов."
  echo ""
  exit 0
fi

# --- Вычисление ширины столбцов Docker-секции ---
max_port_len=4
max_type_len=3
max_name_len=10
max_image_len=5
max_id_len=2

for key in "${!docker_ports_info[@]}"; do
  IFS="|" read -r port proto <<< "$key"
  IFS="|" read -r name image container_id <<< "${docker_ports_info[$key]}"
  [[ ${#port} -gt $max_port_len ]] && max_port_len=${#port}
  [[ ${#proto} -gt $max_type_len ]] && max_type_len=${#proto}
  [[ ${#name} -gt $max_name_len ]] && max_name_len=${#name}
  [[ ${#image} -gt $max_image_len ]] && max_image_len=${#image}
  [[ ${#container_id} -gt $max_id_len ]] && max_id_len=${#container_id}
done

((max_port_len+=2))
((max_type_len+=2))
((max_name_len+=2))
((max_image_len+=2))
((max_id_len+=2))

# --- Вывод Docker-секции ---
echo ""
echo "Порты, занятые Docker-контейнерами:"
printf "\n%-*s %-*s %-*s %-*s %-*s\n" \
  $max_port_len "Порт" \
  $max_type_len "Тип" \
  $max_name_len "Контейнер" \
  $max_image_len "Образ" \
  $max_id_len "ID"

for key in "${sorted_ports[@]}"; do
  IFS="|" read -r port proto <<< "$key"
  if [[ -n "${docker_ports_info[$key]}" ]]; then
    IFS="|" read -r name image container_id <<< "${docker_ports_info[$key]}"
    printf "%-*s %-*s %-*s %-*s %-*s\n" \
      $max_port_len "$port" \
      $max_type_len "$proto" \
      $max_name_len "$name" \
      $max_image_len "$image" \
      $max_id_len "$container_id"
  fi
done

# --- Вывод обычных приложений ---
echo ""
echo "Порты, занятые обычными приложениями:"
printf "\n%-10s %-6s %-20s %-6s\n" "Порт" "Тип" "Процесс" "PID"

for key in "${sorted_ports[@]}"; do
  if [[ -n "${non_docker_ports_info[$key]}" ]]; then
    IFS="|" read -r port proto pname pid <<< "${non_docker_ports_info[$key]}"
    printf "%-10s %-6s %-20s %-6s\n" "$port" "$proto" "$pname" "$pid"
  fi
done

# --- Вывод строки всех портов ---
echo ""
echo "Все занятые порты:"
all_unique_ports=($(printf "%s\n" "${sorted_ports[@]}" | cut -d'|' -f1 | sort -n | uniq))
echo "${all_unique_ports[*]}"
