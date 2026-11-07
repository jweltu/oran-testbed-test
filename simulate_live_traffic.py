#!/usr/bin/env python3
"""
Simulador de tráfego KPM em tempo real para o Dashboard Grafana do FlexRIC.
Lê os dados de exemplo gravados pelo xApp KPM Monitor e os envia continuamente
atualizando os timestamps para o momento atual (now).
"""

import os
import sys
import time
import argparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FLEXRIC_DIR = os.path.join(SCRIPT_DIR, "O-RAN-Testbed-Automation", "OpenAirInterface_Testbed", "RAN_Intelligent_Controllers", "Flexible-RIC")
LOGS_DIR = os.path.join(FLEXRIC_DIR, "logs")
ADDITIONAL_DIR = os.path.join(FLEXRIC_DIR, "additional_scripts")

def load_rows(file_path):
    if not os.path.isfile(file_path):
        return [], ""
    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        header = f.readline()
        rows = [line.strip() for line in f if line.strip()]
    return rows, header

def main():
    parser = argparse.ArgumentParser(description="Simulador de métricas O-RAN KPM em tempo real")
    parser.add_argument("--interval", type=float, default=1.0, help="Intervalo de envio em segundos (padrão: 1.0)")
    parser.add_argument("--reset", action="store_true", help="Limpa o arquivo CSV e inicia novo histórico")
    args = parser.parse_args()

    os.makedirs(LOGS_DIR, exist_ok=True)

    ue_sample_file = os.path.join(ADDITIONAL_DIR, "sample_KPI_Metrics.csv")
    cell_sample_file = os.path.join(ADDITIONAL_DIR, "sample_KPI_Metrics_Cells.csv")

    ue_log_file = os.path.join(LOGS_DIR, "KPI_Metrics.csv")
    cell_log_file = os.path.join(LOGS_DIR, "KPI_Metrics_Cells.csv")

    ue_rows, ue_header = load_rows(ue_sample_file)
    cell_rows, cell_header = load_rows(cell_sample_file)

    if not ue_rows:
        print(f"[-] Arquivo de exemplo não encontrado: {ue_sample_file}")
        sys.exit(1)

    # Se reset ou arquivo não existir, escreve o cabeçalho
    mode = "w" if (args.reset or not os.path.exists(ue_log_file) or os.path.getsize(ue_log_file) == 0) else "a"
    if mode == "w":
        with open(ue_log_file, "w", encoding="utf-8") as f:
            f.write(ue_header)
        if cell_header:
            with open(cell_log_file, "w", encoding="utf-8") as f:
                f.write(cell_header)
        print(f"[+] Arquivos de log reiniciados em {LOGS_DIR}")

    print("============================================================")
    print("   Simulador de Métricas FlexRIC KPM Iniciado (Tempo Real)  ")
    print("============================================================")
    print(f"[*] Intervalo de atualização: {args.interval}s")
    print(f"[*] Destino: {ue_log_file}")
    print("[*] No Grafana, defina o intervalo de tempo para 'Last 5 minutes' ou 'Last 15 minutes'.")
    print("[*] Pressione Ctrl+C para encerrar.\n")

    ue_count = len(ue_rows)
    cell_count = len(cell_rows) if cell_rows else 0
    idx = 0

    try:
        while True:
            now_ms = int(time.time() * 1000)

            # UE metrics
            ue_line = ue_rows[idx % ue_count]
            parts = ue_line.split(",", 1)
            new_ue_line = f"{now_ms},{parts[1]}\n"

            with open(ue_log_file, "a", encoding="utf-8") as f:
                f.write(new_ue_line)

            # Cell metrics se disponível
            if cell_count > 0:
                cell_line = cell_rows[idx % cell_count]
                cparts = cell_line.split(",", 1)
                new_cell_line = f"{now_ms},{cparts[1]}\n"
                with open(cell_log_file, "a", encoding="utf-8") as f:
                    f.write(new_cell_line)

            # Extrair alguns valores para exibição no console
            cols = parts[1].split(",")
            # cols: BatchID(0), RepOffset(1), Latency(2), E2Node(3), UEID(4), VolDL(5), VolUL(6), Delay(7), ThpDL(8), ThpUL(9), PrbDL(10), PrbUL(11)
            ue_id = cols[4] if len(cols) > 4 else "?"
            thp_dl = cols[8] if len(cols) > 8 else "?"
            thp_ul = cols[9] if len(cols) > 9 else "?"
            prb_dl = cols[10] if len(cols) > 10 else "?"

            print(f"[{time.strftime('%H:%M:%S')}] Timestamp: {now_ms} | UE: {ue_id} | DL Thp: {thp_dl} kbps | UL Thp: {thp_ul} kbps | PRB DL: {prb_dl}%")

            idx += 1
            time.sleep(args.interval)

    except KeyboardInterrupt:
        print("\n[+] Simulação finalizada pelo usuário.")

if __name__ == "__main__":
    main()
