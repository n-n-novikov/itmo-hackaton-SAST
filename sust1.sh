#!/bin/bash

# Параметры по умолчанию
PROJECT_PATH=""
ANALYSIS_MODE="fast"

show_help() {
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  -p, --path <путь>      Путь к проекту для анализа"
    echo "  -m, --mode <режим>     Режим анализа (fast/full)" # Пока есть только fast
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
    semgrep scan --config=/tmp/semgrep-rules "$PROJECT_PATH"
    bearer scan "$PROJECT_PATH"
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
