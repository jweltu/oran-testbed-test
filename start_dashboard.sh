#!/usr/bin/env bash
#
# Script para inicializar o Dashboard Grafana do FlexRIC KPI Monitor
# Compatível com Linux, Docker e GitHub Codespaces.
#

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FLEXRIC_DIR="$SCRIPT_DIR/O-RAN-Testbed-Automation/OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC"
LOGS_DIR="$FLEXRIC_DIR/logs"
ADDITIONAL_DIR="$FLEXRIC_DIR/additional_scripts"
GRAFANA_REPO_DIR="$SCRIPT_DIR/grafana"

echo "============================================================"
echo "    Inicializando Dashboard de Visualização O-RAN (Grafana) "
echo "============================================================"

# 1. Garantir diretórios necessários
mkdir -p "$LOGS_DIR"
sudo mkdir -p /etc/grafana/provisioning/datasources \
             /etc/grafana/provisioning/dashboards \
             /var/lib/grafana/dashboards \
             /var/lib/grafana/plugins-bundled \
             /var/log/grafana
sudo chown -R grafana:grafana /var/lib/grafana /var/log/grafana 2>/dev/null || true

# 2. Garantir dados de amostra se os logs não existirem
if [ ! -f "$LOGS_DIR/KPI_Metrics.csv" ] || [ ! -s "$LOGS_DIR/KPI_Metrics.csv" ]; then
    echo "[+] Copiando dados de exemplo para $LOGS_DIR/KPI_Metrics.csv..."
    cp "$ADDITIONAL_DIR/sample_KPI_Metrics.csv" "$LOGS_DIR/KPI_Metrics.csv"
fi

if [ ! -f "$LOGS_DIR/KPI_Metrics_Cells.csv" ] || [ ! -s "$LOGS_DIR/KPI_Metrics_Cells.csv" ]; then
    echo "[+] Copiando dados de exemplo para $LOGS_DIR/KPI_Metrics_Cells.csv..."
    cp "$ADDITIONAL_DIR/sample_KPI_Metrics_Cells.csv" "$LOGS_DIR/KPI_Metrics_Cells.csv"
fi

# 3. Verificar instalação do plugin Infinity no Grafana
if ! sudo grafana cli --homepath /usr/share/grafana plugins ls 2>/dev/null | grep -q "yesoreyeram-infinity-datasource"; then
    echo "[+] Instalando plugin yesoreyeram-infinity-datasource..."
    sudo grafana cli --homepath /usr/share/grafana plugins install yesoreyeram-infinity-datasource
fi

# 4. Configurar Provisionamento Automático de Datasource e Dashboard
echo "[+] Configurando provisionamento automático de datasource e dashboard..."

sudo cp "$GRAFANA_REPO_DIR/provisioning/datasources/infinity.yaml" /etc/grafana/provisioning/datasources/infinity.yaml
sudo cp "$GRAFANA_REPO_DIR/provisioning/dashboards/dashboards.yaml" /etc/grafana/provisioning/dashboards/dashboards.yaml
sudo cp "$GRAFANA_REPO_DIR/dashboards/flexric_kpi_monitor.json" /var/lib/grafana/dashboards/flexric_kpi_monitor.json
sudo chown grafana:grafana /var/lib/grafana/dashboards/flexric_kpi_monitor.json

# 5. Configurar acesso anônimo no grafana.ini para facilitar o acesso sem login
if [ -f /etc/grafana/grafana.ini ]; then
    sudo sed -i 's/^;enabled = false/enabled = true/' /etc/grafana/grafana.ini
    sudo sed -i 's/^;org_name = Main Org./org_name = Main Org./' /etc/grafana/grafana.ini
    sudo sed -i 's/^;org_role = Viewer/org_role = Admin/' /etc/grafana/grafana.ini
fi

# 6. Iniciar Servidor HTTP Python (porta 3030)
if ! pgrep -f "[p]ython_server_for_grafana.py" >/dev/null; then
    echo "[+] Iniciando servidor de métricas Python na porta 3030..."
    cd "$ADDITIONAL_DIR"
    nohup python3 python_server_for_grafana.py >"$LOGS_DIR/python_server.log" 2>&1 &
    cd "$SCRIPT_DIR"
else
    echo "[i] Servidor Python de métricas já está em execução na porta 3030."
fi

# 7. Iniciar Grafana (porta 3000)
if ! pgrep -f "grafana server" >/dev/null; then
    echo "[+] Iniciando servidor Grafana na porta 3000..."
    sudo su -s /bin/bash grafana -c "nohup /usr/share/grafana/bin/grafana server \
        --homepath=/usr/share/grafana \
        --config=/etc/grafana/grafana.ini \
        --packaging=deb \
        cfg:default.paths.logs=/var/log/grafana \
        cfg:default.paths.data=/var/lib/grafana \
        cfg:default.paths.plugins=/var/lib/grafana/plugins \
        cfg:default.paths.provisioning=/etc/grafana/provisioning \
        cfg:default.paths.bundled_plugins=/var/lib/grafana/plugins-bundled >/var/log/grafana/grafana_server.log 2>&1 &"
else
    echo "[i] Grafana já está em execução na porta 3000."
fi

# Aguardar Grafana inicializar
echo -n "[+] Aguardando serviços responderem"
for i in {1..30}; do
    if curl -s http://localhost:3000/api/health 2>/dev/null | grep -Eq '"database":\s*"ok"'; then
        echo -e "\n[✓] Grafana e servidor de métricas operacionais!"
        break
    fi
    echo -n "."
    sleep 1
done

echo ""
echo "============================================================"
echo "                   Dashboard Pronto!                        "
echo "============================================================"
echo "Acesse o Grafana em:"
echo "  -> Local: http://localhost:3000/d/flexric-kpi-monitor/flexric-kpi-monitor"
if [ -n "$CODESPACE_NAME" ] && [ -n "$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN" ]; then
    echo "  -> Codespace URL: https://${CODESPACE_NAME}-3000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/d/flexric-kpi-monitor/flexric-kpi-monitor"
fi
echo ""
echo "Credenciais padrão (caso solicitadas):"
echo "  Usuário: admin"
echo "  Senha:   admin"
echo ""
echo "Modos de uso das métricas:"
echo "  1) Dados Históricos / Amostra: no seletor de tempo do Grafana, escolha o intervalo dos dados de amostra (ex: 26 de Outubro de 2026 das 18:35 às 18:50 UTC)."
echo "  2) Simulação em Tempo Real: execute em outro terminal:"
echo "       python3 simulate_live_traffic.py"
echo "     (E no Grafana selecione 'Last 5 minutes' com refresh automático de 1s ou 5s)"
echo "  3) Testbed Real (OpenAirInterface + FlexRIC): execute o cenário de teste oficial:"
echo "       cd O-RAN-Testbed-Automation/OpenAirInterface_Testbed"
echo "       ./run_with_grafana_dashboard.sh"
echo ""
echo "Para parar os serviços do dashboard:"
echo "  ./stop_dashboard.sh"
echo "============================================================"
