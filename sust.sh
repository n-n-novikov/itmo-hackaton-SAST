#!/bin/bash

# Параметры по умолчанию
ORIGINAL_DIR=$(pwd)
PROJECT_PATH=""
ANALYSIS_MODE="fast"
BEARER_RULES=""
SEMGREP_RULES="$SUST_INSTALL_DIR/rules/semgrep-rules"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

#выход, в случае если произошла ошибка
set -e

show_help() {
    echo $SUST_INSTALL_DIR
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  -p, --path <путь>        Путь к проекту для анализа"
    echo "  -m, --mode <режим>       Режим анализа (fast/full)"
    echo "  -b, --bearer-rules <путь> Путь к правилам bearer"
    echo "  -s, --semgrep-rules <путь> Путь к правилам semgrep. По умолчанию - $SUST_INSTALL_DIR/rules/semgrep_rules"
    exit 1
}

#Обработка параметров
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

#Проверка обязательных параметров
if [ -z "$PROJECT_PATH" ]; then
    echo "Ошибка: Необходимо указать путь к проекту (-p/--path)"
    show_help
fi

#Быстрый анализ (semgrep/bearer)
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

create_codeql_db() {
    local LANGUAGES
    echo "Попытка обнаружить используемый язык в проекте..."

    if find "$PROJECT_PATH" -name "*.py" -o -name "requirements.txt" -o -name "setup.py" | grep -q .; then
        LANGUAGES+=("python")
    fi

    if find "$PROJECT_PATH" -name "*.c" -o -name "*.cpp" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" | grep -q .; then
        LANGUAGES+=("c-cpp")
    fi

    if find "$PROJECT_PATH" -name "*.java" -o -name "*.kt" -o -name "build.gradle" | grep -q .; then
        LANGUAGES+=("java-kotlin")
    fi

    if find "$PROJECT_PATH" -name "*.js" -o -name "*.ts" -o -name "package.json" | grep -q .; then
        LANGUAGES+=("javascript-typescript")
    fi

    if find "$PROJECT_PATH" -name "*.cs" -o -name "*.csproj" -o -name "*.sln" | grep -q .; then
        LANGUAGES+=("csharp")
    fi

    if find "$PROJECT_PATH" -name "*.go" -o -name "go.mod" | grep -q .; then
        LANGUAGES+=("go")
    fi

    if find "$PROJECT_PATH" -name "*.rb" -o -name "Gemfile" | grep -q .; then
        LANGUAGES+=("ruby")
    fi

    if find "$PROJECT_PATH" -name "*.swift" -o -name "Package.swift" | grep -q .; then
        LANGUAGES+=("swift")
    fi

    if find "$PROJECT_PATH" -name "*.rs" -o -name "Cargo.toml" | grep -q .; then
        echo "В проекте были обнаружены файлы .rs или Cargo.toml, но Rust не поддерживается в CodeQL"
    fi

    #we can add more language checks probably

    if [ -z "${LANGUAGES[*]}" ]; then
        echo "Не обнаружен подходящий язык программирования в пути проекта, запустить полный анализ не получится"
        exit 1
    fi

    if [ ${#LANGUAGES[@]} -gt 1 ]; then
        echo "В проекте несколько языков программирования ${LANGUAGES[@]}, используем --db-cluster"
        local LANG_ARGUMENT=$(printf "%s," "${LANGUAGES[@]}")
        LANG_ARGUMENT="${LANG_ARGUMENT%,}"
        #наверное можно заглушить стандартный вывод из codeql но пусть будет
        $SUST_INSTALL_DIR/codeql/codeql database create --db-cluster sust_analysis_db --language $LANG_ARGUMENT
    else
        echo "В проекте обнаружен следующий язык программирования: ${LANGUAGES[0]}"
        echo -e "Запуск CodeQL..."
        $SUST_INSTALL_DIR/codeql/codeql database create sust_analysis_db --language ${LANGUAGES[0]}
    fi
}


run_full_analysis() {
    run_fast_analysis
    echo "Запуск продвинутой проверки..."
    cd "$PROJECT_PATH"

    create_codeql_db
    $SUST_INSTALL_DIR/codeql/codeql database analyze sust_db --format=csv --output=$ORIGINAL_DIR/codeql_report_${TIMESTAMP}.csv
    rm -rf sust_analysis_db
    cd "$ORIGINAL_DIR"
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
