#!/bin/bash

# Параметры по умолчанию
PROJECT_PATH=""
ANALYSIS_MODE="fast"
BEARER_RULES=""
SEMGREP_RULES=""
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

show_help() {
    echo $SUST_INSTALL_DIR
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  -p, --path <путь>        Путь к проекту для анализа"
    echo "  -m, --mode <режим>       Режим анализа (fast/full)"
    echo "  -b, --bearer-rules <путь> Путь к правилам bearer"
    echo "  -s, --semgrep-rules <путь> Путь к правилам semgrep"
    exit 1
}

# Обработка параметров
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--path)
            PROJECT_PATH="$2"
            shift 2
            ;;
        -m|--mode)
            ANALYSIS_MODE="$2"
            shift 2
            ;;
        -b|--bearer-rules)
            BEARER_RULES="$2"
            shift 2
            ;;
        -s|--semgrep-rules)
            SEMGREP_RULES="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Неизвестный параметр: $1"
            show_help
            ;;
    esac
done

# Проверка обязательных параметров
if [ -z "$PROJECT_PATH" ]; then
    echo "Ошибка: Необходимо указать путь к проекту (-p/--path)"
    show_help
fi

# Быстрый анализ (semgrep/bearer)
run_fast_analysis() {
    echo "Запуск быстрой проверки..."
    
    # Запуск semgrep с правилами, если они указаны
    if [ -n "$SEMGREP_RULES" ]; then
        semgrep scan --config="$SEMGREP_RULES" "$PROJECT_PATH" -o semgrep_report_${TIMESTAMP}.log
    else
        semgrep scan --config=auto "$PROJECT_PATH" -o semgrep_report_${TIMESTAMP}.log
    fi
    
    # Запуск bearer с правилами, если они указаны
    if [ -n "$BEARER_RULES" ]; then
        bearer scan "$PROJECT_PATH" --external-rule-dir "$BEARER_RULES" --output bearer_sast_report_${TIMESTAMP}.log
        bearer scan "$PROJECT_PATH" --external-rule-dir "$BEARER_RULES" --scanner secrets --output bearer_secrets_report_${TIMESTAMP}.log
    else
        bearer scan "$PROJECT_PATH" --output bearer_sast_report_${TIMESTAMP}.log
        bearer scan "$PROJECT_PATH" --scanner secrets --output bearer_secrets_report_${TIMESTAMP}.log
    fi
}

# Основной процесс
case "$ANALYSIS_MODE" in
    fast)
        run_fast_analysis
        ;;
    full)
        run_full_analysis
        ;;
    *)
        echo "Ошибка: Неверный режим анализа. Используйте 'fast' или 'full'"
        exit 1
        ;;
esac
