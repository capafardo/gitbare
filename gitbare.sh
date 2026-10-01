#!/usr/bin/env bash
# ==============================================================================
# Git Bare Manager - Gerenciador Git com foco em Hub Bare Local
# ==============================================================================

# Cores ANSI
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_CYAN="\033[36m"
C_GRAY="\033[90m"

# Arquivo de configuração persistente
CONFIG_DIR="$HOME/.config/gitbare"
CONFIG_FILE="$CONFIG_DIR/config"
DEFAULT_BARE_HUB="$HOME/git-bare-hub"

# ------------------------------------------------------------------------------
# Funções de Configuração e Ambiente
# ------------------------------------------------------------------------------

carregar_configuracao() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi

    if [[ -z "$BARE_HUB_DIR" ]]; then
        BARE_HUB_DIR="$DEFAULT_BARE_HUB"
    fi

    # Garante que a pasta bare hub exista
    if [[ ! -d "$BARE_HUB_DIR" ]]; then
        mkdir -p "$BARE_HUB_DIR" 2>/dev/null
    fi
}

salvar_configuracao() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    cat <<EOF > "$CONFIG_FILE"
# Configuração do Git Bare Manager
BARE_HUB_DIR="$BARE_HUB_DIR"
EOF
}

pausar() {
    echo ""
    echo -e "${C_GRAY}──────────────────────────────────────────────────${C_RESET}"
    read -rp "Pressione [ENTER] para continuar..." _
}

verificar_git() {
    if ! command -v git &>/dev/null; then
        echo -e "${C_RED}[ERRO] Git não está instalado neste sistema.${C_RESET}"
        exit 1
    fi
}

e_repositorio_git() {
    git rev-parse --is-inside-work-tree &>/dev/null
}

obter_branch_atual() {
    git branch --show-current 2>/dev/null || echo "sem-branch"
}

# ------------------------------------------------------------------------------
# Cabeçalho Padronizado
# ------------------------------------------------------------------------------

cabecalho() {
    clear
    local status_git=""
    local branch=""

    if e_repositorio_git; then
        branch=$(obter_branch_atual)
        local remote_origin
        remote_origin=$(git remote get-url origin 2>/dev/null || echo "nenhum")
        status_git="${C_GREEN}● Git Ativo${C_RESET} | Branch: ${C_CYAN}${branch}${C_RESET} | Origin: ${C_YELLOW}${remote_origin}${C_RESET}"
    else
        status_git="${C_YELLOW}○ Não é um repositório Git${C_RESET}"
    fi

    echo -e "${C_BLUE}${C_BOLD}========================================================================${C_RESET}"
    echo -e "${C_BOLD}                     GIT BARE MANAGER - MODO TERMINAL${C_RESET}"
    echo -e "${C_BLUE}========================================================================${C_RESET}"
    echo -e "${C_BOLD}Pasta de Trabalho :${C_RESET} ${C_CYAN}$PWD${C_RESET}"
    echo -e "${C_BOLD}Servidor Bare Hub :${C_RESET} ${C_YELLOW}$BARE_HUB_DIR${C_RESET}"
    echo -e "${C_BOLD}Status Local      :${C_RESET} $status_git"
    echo -e "${C_BLUE}========================================================================${C_RESET}"
    echo ""
}

# ------------------------------------------------------------------------------
# 1. Iniciar Novo Projeto (Bare Hub + Repositório Local + Vínculo)
# ------------------------------------------------------------------------------

iniciar_novo_projeto() {
    cabecalho
    echo -e "${C_BOLD}${C_CYAN}--- INICIAR NOVO PROJETO COM BARE HUB ---${C_RESET}\n"

    local nome_padrao
    nome_padrao=$(basename "$PWD")

    read -rp "Nome do repositório no Bare Hub [$nome_padrao]: " nome_repo
    nome_repo="${nome_repo:-$nome_padrao}"
    nome_repo="${nome_repo%.git}.git"

    local caminho_bare="$BARE_HUB_DIR/$nome_repo"

    # 1. Configurar Bare no Hub
    echo ""
    if [[ -d "$caminho_bare" ]]; then
        echo -e "${C_YELLOW}[AVISO] O repositório bare '$nome_repo' já existe no Hub.${C_RESET}"
    else
        echo -e "${C_CYAN}1. Criando repositório bare no servidor local...${C_RESET}"
        git init --bare "$caminho_bare"
        echo -e "${C_GREEN}✓ Repositório Bare criado em:${C_RESET} $caminho_bare"
    fi

    # 2. Inicializar Pasta Local
    echo ""
    if ! e_repositorio_git; then
        echo -e "${C_CYAN}2. Inicializando repositório Git na pasta atual...${C_RESET}"
        git init -b main 2>/dev/null || git init
        echo -e "${C_GREEN}✓ Repositório Git local inicializado.${C_RESET}"
    else
        echo -e "${C_GREEN}✓ Pasta atual já é um repositório Git.${C_RESET}"
    fi

    # 3. Vincular Remote Origin
    echo ""
    echo -e "${C_CYAN}3. Vinculando o remote origin ao bare local...${C_RESET}"
    if git remote | grep -q "^origin$"; then
        git remote set-url origin "$caminho_bare"
        echo -e "${C_GREEN}✓ Remote 'origin' atualizado para:${C_RESET} $caminho_bare"
    else
        git remote add origin "$caminho_bare"
        echo -e "${C_GREEN}✓ Remote 'origin' adicionado:${C_RESET} $caminho_bare"
    fi

    # 4. Primeiro commit opcional
    echo ""
    read -rp "Deseja criar um commit inicial e enviar (push) para o bare? (s/N): " resp_commit
    if [[ "$resp_commit" =~ ^[sS]$ ]]; then
        if [[ ! -f "README.md" ]] && [[ ! -f "readme.md" ]]; then
            echo "# ${nome_repo%.git}" > README.md
            echo "Projeto inicializado via Git Bare Manager." >> README.md
        fi
        git add -A
        git commit -m "Commit inicial" || true
        local branch
        branch=$(obter_branch_atual)
        git push -u origin "$branch"
        echo -e "${C_GREEN}✓ Commit inicial enviado com sucesso para o Bare Hub!${C_RESET}"
    fi

    pausar
}

# ------------------------------------------------------------------------------
# 2. Clonagem (Local Bare e Remoto)
# ------------------------------------------------------------------------------

menu_clonagem() {
    while true; do
        cabecalho
        echo -e "${C_BOLD}${C_CYAN}--- CLONAGEM DE REPOSITÓRIOS ---${C_RESET}\n"
        echo -e "  ${C_BOLD}1)${C_RESET} Clonar a partir do Servidor Bare Local"
        echo -e "  ${C_BOLD}2)${C_RESET} Clonar de URL Remota (GitHub, GitLab, SSH/HTTPS)"
        echo -e "  ${C_BOLD}3)${C_RESET} Espelhar repositório remoto como Bare no Servidor Local"
        echo -e "  ${C_BOLD}0)${C_RESET} Voltar ao menu principal\n"
        read -rp "Escolha uma opção: " op_clone

        case "$op_clone" in
            1) clonar_do_bare_local ;;
            2) clonar_remoto ;;
            3) clonar_remoto_para_bare ;;
            0) break ;;
            *) echo -e "${C_RED}Opção inválida.${C_RESET}"; sleep 1 ;;
        esac
    done
}

clonar_do_bare_local() {
    cabecalho
    echo -e "${C_BOLD}${C_CYAN}--- CLONAR DO SERVIDOR BARE LOCAL ---${C_RESET}\n"

    # Listar repositórios no Bare Hub
    mapfile -t repos < <(find "$BARE_HUB_DIR" -maxdepth 1 -mindepth 1 -type d -name "*.git" -printf "%f\n" 2>/dev/null | sort)

    if [[ ${#repos[@]} -eq 0 ]]; then
        echo -e "${C_YELLOW}Nenhum repositório .git encontrado em $BARE_HUB_DIR${C_RESET}"
        pausar
        return
    fi

    echo "Repositórios disponíveis no Hub:"
    for i in "${!repos[@]}"; do
        echo -e "  ${C_BOLD}$((i+1)))${C_RESET} ${repos[$i]}"
    done
    echo ""
    read -rp "Selecione o número do repositório (ou 0 para cancelar): " num

    if [[ "$num" == "0" ]] || [[ -z "$num" ]]; then
        return
    fi

    if ! [[ "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > ${#repos[@]} )); then
        echo -e "${C_RED}Seleção inválida.${C_RESET}"
        pausar
        return
    fi

    local repo_selecionado="${repos[$((num-1))]}"
    local nome_destino="${repo_selecionado%.git}"

    echo ""
    read -rp "Diretório de destino [$nome_destino]: " destino
    destino="${destino:-$nome_destino}"

    echo ""
    echo -e "${C_CYAN}Clonando $BARE_HUB_DIR/$repo_selecionado em $destino...${C_RESET}"
    git clone "$BARE_HUB_DIR/$repo_selecionado" "$destino"
    echo -e "${C_GREEN}✓ Clonagem concluída com sucesso!${C_RESET}"
    pausar
}

clonar_remoto() {
    cabecalho
    echo -e "${C_BOLD}${C_CYAN}--- CLONAR DE URL REMOTA ---${C_RESET}\n"
    read -rp "URL remota (ex: https://github.com/usuario/repo.git): " url_remota
    if [[ -z "$url_remota" ]]; then
        return
    fi

    read -rp "Pasta de destino (deixe vazio para padrão): " pasta_destino
    echo ""
    echo -e "${C_CYAN}Clonando...${C_RESET}"
    if [[ -n "$pasta_destino" ]]; then
        git clone "$url_remota" "$pasta_destino"
    else
        git clone "$url_remota"
    fi
    echo -e "${C_GREEN}✓ Clonagem finalizada!${C_RESET}"
    pausar
}

clonar_remoto_para_bare() {
    cabecalho
    echo -e "${C_BOLD}${C_CYAN}--- ESPELHAR REMOTO NO SERVIDOR BARE LOCAL ---${C_RESET}\n"
    read -rp "URL remota para clonar como Bare: " url_remota
    if [[ -z "$url_remota" ]]; then
        return
    fi

    local nome_sugerido
    nome_sugerido=$(basename "$url_remota")
    [[ "$nome_sugerido" != *.git ]] && nome_sugerido="${nome_sugerido}.git"

    read -rp "Nome do Bare no Hub [$nome_sugerido]: " nome_bare
    nome_bare="${nome_bare:-$nome_sugerido}"

    echo ""
    echo -e "${C_CYAN}Clonando como Bare em $BARE_HUB_DIR/$nome_bare...${C_RESET}"
    git clone --bare "$url_remota" "$BARE_HUB_DIR/$nome_bare"
    echo -e "${C_GREEN}✓ Repositório Bare criado no Hub local com sucesso!${C_RESET}"
    pausar
}

# ------------------------------------------------------------------------------
# 3. Operações Diárias
# ------------------------------------------------------------------------------

menu_operacoes() {
    if ! e_repositorio_git; then
        cabecalho
        echo -e "${C_RED}[AVISO] A pasta atual ($PWD) não é um repositório Git.${C_RESET}"
        echo -e "Use a opção 1 do menu principal para iniciar um novo projeto aqui ou clonar."
        pausar
        return
    fi

    while true; do
        cabecalho
        echo -e "${C_BOLD}${C_CYAN}--- OPERAÇÕES DIÁRIAS (MONOUSUÁRIO) ---${C_RESET}\n"
        echo -e "  ${C_BOLD}1)${C_RESET} Status detalhado"
        echo -e "  ${C_BOLD}2)${C_RESET} Adicionar todos os arquivos e Commitar"
        echo -e "  ${C_BOLD}3)${C_RESET} Adicionar interativamente / arquivos específicos e Commitar"
        echo -e "  ${C_BOLD}4)${C_RESET} Enviar alterações (git push origin)"
        echo -e "  ${C_BOLD}5)${C_RESET} Puxar alterações (git pull origin)"
        echo -e "  ${C_BOLD}6)${C_RESET} Histórico de Commits (Log visual)"
        echo -e "  ${C_BOLD}7)${C_RESET} Ver Diferenças (git diff)"
        echo -e "  ${C_BOLD}0)${C_RESET} Voltar ao menu principal\n"
        read -rp "Escolha uma opção: " op_ops

        case "$op_ops" in
            1)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- STATUS DETALHADO ---${C_RESET}\n"
                git status
                pausar
                ;;
            2)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- ADICIONAR TUDO E COMMITAR ---${C_RESET}\n"
                git status -s
                echo ""
                read -rp "Mensagem do commit (deixe vazio para cancelar): " msg
                if [[ -n "$msg" ]]; then
                    git add -A
                    git commit -m "$msg"
                    echo -e "\n${C_GREEN}✓ Commit realizado com sucesso!${C_RESET}"
                else
                    echo -e "${C_YELLOW}Operação cancelada.${C_RESET}"
                fi
                pausar
                ;;
            3)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- ADICIONAR ARQUIVOS ESPECÍFICOS ---${C_RESET}\n"
                git status -s
                echo ""
                read -rp "Arquivos a adicionar (separados por espaço, ou Enter para interativo): " arqs
                if [[ -z "$arqs" ]]; then
                    git add -p
                else
                    # shellcheck disable=SC2086
                    git add $arqs
                fi
                echo ""
                read -rp "Mensagem do commit (deixe vazio para não commitar agora): " msg
                if [[ -n "$msg" ]]; then
                    git commit -m "$msg"
                    echo -e "\n${C_GREEN}✓ Commit realizado com sucesso!${C_RESET}"
                fi
                pausar
                ;;
            4)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- ENVIAR ALTERAÇÕES (PUSH) ---${C_RESET}\n"
                local branch
                branch=$(obter_branch_atual)
                echo -e "Enviando branch ${C_CYAN}$branch${C_RESET} para o remote origin..."
                git push origin "$branch" 2>&1 || git push -u origin "$branch"
                pausar
                ;;
            5)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- PUXAR ALTERAÇÕES (PULL) ---${C_RESET}\n"
                local branch
                branch=$(obter_branch_atual)
                echo -e "Puxando alterações da branch ${C_CYAN}$branch${C_RESET}..."
                git pull origin "$branch"
                pausar
                ;;
            6)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- HISTÓRICO DE COMMITS ---${C_RESET}\n"
                git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit -n 15
                echo ""
                pausar
                ;;
            7)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- DIFERENÇAS (DIFF) ---${C_RESET}\n"
                echo -e "${C_YELLOW}[Arquivos modificados ainda não staged]:${C_RESET}"
                git diff --stat
                echo ""
                read -rp "Deseja ver o diff completo linha a linha? (s/N): " ver_completo
                if [[ "$ver_completo" =~ ^[sS]$ ]]; then
                    git diff
                fi
                echo ""
                echo -e "${C_YELLOW}[Arquivos staged prontos para commit]:${C_RESET}"
                git diff --cached --stat
                pausar
                ;;
            0) break ;;
            *) echo -e "${C_RED}Opção inválida.${C_RESET}"; sleep 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 4. Desfazer e Recuperar
# ------------------------------------------------------------------------------

menu_desfazer() {
    if ! e_repositorio_git; then
        cabecalho
        echo -e "${C_RED}[AVISO] A pasta atual ($PWD) não é um repositório Git.${C_RESET}"
        pausar
        return
    fi

    while true; do
        cabecalho
        echo -e "${C_BOLD}${C_CYAN}--- DESFAZER E RECUPERAR ---${C_RESET}\n"
        echo -e "  ${C_BOLD}1)${C_RESET} Desfazer último commit mantendo alterações nos arquivos (${C_GREEN}Soft Reset${C_RESET})"
        echo -e "  ${C_BOLD}2)${C_RESET} Desfazer último commit descartando alterações (${C_RED}Hard Reset${C_RESET})"
        echo -e "  ${C_BOLD}3)${C_RESET} Descartar alterações não commitadas em todos os arquivos"
        echo -e "  ${C_BOLD}4)${C_RESET} Salvar alterações temporariamente no Stash"
        echo -e "  ${C_BOLD}5)${C_RESET} Restaurar alterações do Stash (pop)"
        echo -e "  ${C_BOLD}6)${C_RESET} Listar Stashes existentes"
        echo -e "  ${C_BOLD}0)${C_RESET} Voltar ao menu principal\n"
        read -rp "Escolha uma opção: " op_undo

        case "$op_undo" in
            1)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- DESFAZER ÚLTIMO COMMIT (SOFT RESET) ---${C_RESET}\n"
                if ! git rev-parse --verify HEAD~1 &>/dev/null; then
                    echo -e "${C_YELLOW}[AVISO] Há apenas 1 commit no repositório. Não é possível usar HEAD~1.${C_RESET}"
                    pausar
                    continue
                fi
                echo -e "Último commit que será desfeito:"
                git log -1 --oneline
                echo ""
                read -rp "Confirma desfazer este commit mantendo os arquivos intactos no seu workspace? (s/N): " conf
                if [[ "$conf" =~ ^[sS]$ ]]; then
                    git reset --soft HEAD~1
                    echo -e "${C_GREEN}✓ Último commit desfeito! Suas alterações continuam nos arquivos.${C_RESET}"
                fi
                pausar
                ;;
            2)
                cabecalho
                echo -e "${C_BOLD}${C_RED}--- DESFAZER ÚLTIMO COMMIT (HARD RESET - DESTRUTIVO) ---${C_RESET}\n"
                if ! git rev-parse --verify HEAD~1 &>/dev/null; then
                    echo -e "${C_YELLOW}[AVISO] Há apenas 1 commit no repositório. Não é possível usar HEAD~1.${C_RESET}"
                    pausar
                    continue
                fi
                echo -e "Último commit que será PERDIDO:"
                git log -1 --oneline
                echo ""
                echo -e "${C_RED}${C_BOLD}ATENÇÃO: Todas as alterações feitas nesse commit serão apagadas!${C_RESET}"
                read -rp "Digite 'CONFIRMAR' para prosseguir: " conf_hard
                if [[ "$conf_hard" == "CONFIRMAR" ]]; then
                    git reset --hard HEAD~1
                    echo -e "${C_GREEN}✓ Commit e alterações descartados com sucesso.${C_RESET}"
                else
                    echo -e "${C_YELLOW}Operação cancelada.${C_RESET}"
                fi
                pausar
                ;;
            3)
                cabecalho
                echo -e "${C_BOLD}${C_RED}--- DESCARTAR ALTERAÇÕES NÃO COMMITADAS ---${C_RESET}\n"
                git status -s
                echo ""
                read -rp "Deseja descartar TODAS as alterações não commitadas acima? (s/N): " conf_disc
                if [[ "$conf_disc" =~ ^[sS]$ ]]; then
                    git restore . 2>/dev/null || git checkout -- .
                    git clean -fd
                    echo -e "${C_GREEN}✓ Diretório de trabalho limpo.${C_RESET}"
                fi
                pausar
                ;;
            4)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- SALVAR NO STASH ---${C_RESET}\n"
                read -rp "Mensagem de identificação do Stash: " msg_stash
                if [[ -n "$msg_stash" ]]; then
                    git stash push -m "$msg_stash"
                else
                    git stash
                fi
                echo -e "${C_GREEN}✓ Alterações guardadas no Stash.${C_RESET}"
                pausar
                ;;
            5)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- RECUPERAR STASH ---${C_RESET}\n"
                git stash pop
                pausar
                ;;
            6)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- LISTA DE STASHES ---${C_RESET}\n"
                git stash list
                pausar
                ;;
            0) break ;;
            *) echo -e "${C_RED}Opção inválida.${C_RESET}"; sleep 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 5. Gerenciamento de Branches
# ------------------------------------------------------------------------------

menu_branches() {
    if ! e_repositorio_git; then
        cabecalho
        echo -e "${C_RED}[AVISO] A pasta atual ($PWD) não é um repositório Git.${C_RESET}"
        pausar
        return
    fi

    while true; do
        cabecalho
        echo -e "${C_BOLD}${C_CYAN}--- GERENCIAR BRANCHES ---${C_RESET}\n"
        echo -e "  ${C_BOLD}1)${C_RESET} Listar branches (locais e remotas)"
        echo -e "  ${C_BOLD}2)${C_RESET} Criar nova branch e alternar para ela"
        echo -e "  ${C_BOLD}3)${C_RESET} Alternar branch (checkout)"
        echo -e "  ${C_BOLD}4)${C_RESET} Excluir branch local"
        echo -e "  ${C_BOLD}0)${C_RESET} Voltar ao menu principal\n"
        read -rp "Escolha uma opção: " op_br

        case "$op_br" in
            1)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- LISTA DE BRANCHES ---${C_RESET}\n"
                git branch -a
                pausar
                ;;
            2)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- CRIAR E ALTERNAR BRANCH ---${C_RESET}\n"
                read -rp "Nome da nova branch: " nova_br
                if [[ -n "$nova_br" ]]; then
                    git checkout -b "$nova_br"
                    echo -e "${C_GREEN}✓ Branch '$nova_br' criada e ativada.${C_RESET}"
                fi
                pausar
                ;;
            3)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- ALTERNAR BRANCH ---${C_RESET}\n"
                git branch
                echo ""
                read -rp "Nome da branch para alternar: " nome_br
                if [[ -n "$nome_br" ]]; then
                    git checkout "$nome_br"
                fi
                pausar
                ;;
            4)
                cabecalho
                echo -e "${C_BOLD}${C_CYAN}--- EXCLUIR BRANCH LOCAL ---${C_RESET}\n"
                git branch
                echo ""
                read -rp "Nome da branch a ser excluída: " del_br
                if [[ -n "$del_br" ]]; then
                    read -rp "Confirma exclusão da branch '$del_br'? (s/N): " conf_del
                    if [[ "$conf_del" =~ ^[sS]$ ]]; then
                        git branch -d "$del_br" || git branch -D "$del_br"
                    fi
                fi
                pausar
                ;;
            0) break ;;
            *) echo -e "${C_RED}Opção inválida.${C_RESET}"; sleep 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 6. Configurar Servidor Bare Local (Hub)
# ------------------------------------------------------------------------------

configurar_servidor_bare() {
    cabecalho
    echo -e "${C_BOLD}${C_CYAN}--- CONFIGURAR SERVIDOR BARE LOCAL ---${C_RESET}\n"
    echo -e "Diretório atual do Servidor Bare: ${C_YELLOW}$BARE_HUB_DIR${C_RESET}\n"
    read -rp "Novo caminho absoluto para a pasta Bare Hub (Enter para manter): " novo_caminho

    if [[ -n "$novo_caminho" ]]; then
        # Expandir ~ se presente
        novo_caminho="${novo_caminho/#\~/$HOME}"
        mkdir -p "$novo_caminho" 2>/dev/null
        if [[ -d "$novo_caminho" ]]; then
            BARE_HUB_DIR="$novo_caminho"
            salvar_configuracao
            echo -e "\n${C_GREEN}✓ Servidor Bare Hub atualizado para:${C_RESET} $BARE_HUB_DIR"
        else
            echo -e "\n${C_RED}[ERRO] Não foi possível criar/acessar o diretório informado.${C_RESET}"
        fi
    fi
    pausar
}

# ------------------------------------------------------------------------------
# Menu Principal
# ------------------------------------------------------------------------------

menu_principal() {
    while true; do
        cabecalho
        echo -e "${C_BOLD}Selecione uma opção:${C_RESET}\n"
        echo -e "  ${C_BOLD}1)${C_RESET} Iniciar Novo Projeto (Bare Hub + Repositório Local + Vínculo Origin)"
        echo -e "  ${C_BOLD}2)${C_RESET} Clonar Repositório (Do Bare Local ou Remoto)"
        echo -e "  ${C_BOLD}3)${C_RESET} Operações Diárias (Status, Commit, Push, Pull, Log, Diff)"
        echo -e "  ${C_BOLD}4)${C_RESET} Desfazer / Recuperar (Desfazer commit, Descartar mudanças, Stash)"
        echo -e "  ${C_BOLD}5)${C_RESET} Gerenciar Branches (Listar, Criar, Alternar, Excluir)"
        echo -e "  ${C_BOLD}6)${C_RESET} Configurar Pasta do Servidor Bare Local"
        echo -e "  ${C_BOLD}0)${C_RESET} Sair\n"
        read -rp "Opção: " opcao

        case "$opcao" in
            1) iniciar_novo_projeto ;;
            2) menu_clonagem ;;
            3) menu_operacoes ;;
            4) menu_desfazer ;;
            5) menu_branches ;;
            6) configurar_servidor_bare ;;
            0)
                clear
                echo -e "${C_GREEN}Até logo!${C_RESET}"
                exit 0
                ;;
            *)
                echo -e "${C_RED}Opção inválida.${C_RESET}"
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Ponto de Entrada
# ------------------------------------------------------------------------------

verificar_git
carregar_configuracao
menu_principal
