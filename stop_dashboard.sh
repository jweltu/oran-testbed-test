#!/usr/bin/env bash
#
# Script para finalizar o Dashboard Grafana e os servidores de suporte
#

echo "============================================================"
echo "    Parando Serviços do Dashboard (Grafana + Servidores)    "
echo "============================================================"

# Parar simulador de tráfego se estiver ativo
if pgrep -f "simulate_live_traffic.py" >/dev/null; then
    echo "[+] Parando simulador de tráfego..."
    pkill -f "simulate_live_traffic.py" || true
fi

# Parar servidor Python
if pgrep -f "[p]ython_server_for_grafana.py" >/dev/null; then
    echo "[+] Parando servidor Python de métricas (porta 3030)..."
    pkill -9 -f "python_server_for_grafana.py" || true
else
    echo "[i] Servidor Python de métricas já está parado."
fi

# Parar servidor Grafana
if pgrep -f "grafana server" >/dev/null; then
    echo "[+] Parando servidor Grafana (porta 3000)..."
    sudo pkill -f "grafana server" || true
else
    echo "[i] Grafana já está parado."
fi

echo "[✓] Todos os serviços do dashboard foram finalizados."
