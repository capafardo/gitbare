# Git Bare Manager

Shell script interativo para Linux voltado ao gerenciamento simplificado do Git no terminal, com foco em repositórios **Bare** como servidor/hub local de sincronização e backup monousuário.

---

## 🚀 Como Executar

Dê permissão de execução (se necessário) e execute o script diretamente no terminal:

```bash
chmod +x gitbare.sh
./gitbare.sh
```

> **Dica:** Você pode criar um atalho no seu `~/.bashrc` ou `~/.zshrc`:
> ```bash
> alias gitbare="/home/marcelo/projetos/shell/gitbare/gitbare.sh"
> ```
> Dessa forma, basta rodar `gitbare` dentro de qualquer pasta de projeto.

---

## 📋 Funcionalidades

### 1. Iniciar Novo Projeto (Bare Hub + Repositório Local + Vínculo Origin)
1. Pergunta o nome do repositório no servidor Bare Hub (sugere o nome da pasta atual).
2. Cria o repositório `--bare` central na pasta do Hub local (`~/git-bare-hub/<projeto>.git`).
3. Inicializa o repositório local de trabalho (`git init`).
4. Configura automaticamente o remote `origin` apontando para o bare local.
5. Permite gerar um primeiro commit e fazer o primeiro push inicial.

### 2. Clonagem
- **Do Servidor Bare Local**: Lista automaticamente todos os `.git` existentes na pasta Hub para você escolher por número e clonar.
- **De URL Remota**: Clona repositórios externos (GitHub, GitLab, SSH/HTTPS).
- **Espelhar Remoto no Hub Bare**: Clona diretamente para o Hub local com flag `--bare`.

### 3. Operações Diárias (Monousuário)
- Status detalhado e resumido.
- Adicionar tudo e commitar com mensagem personalizada.
- Adicionar interativamente ou arquivos específicos.
- Enviar alterações (`git push origin <branch>`).
- Puxar alterações (`git pull origin <branch>`).
- Histórico visual formatado com gráfico de branches.
- Ver diferenças (Diff não commitado e staged).

### 4. Desfazer e Recuperar
- **Soft Reset**: Desfaz o último commit mantendo intactas as alterações nos seus arquivos.
- **Hard Reset**: Desfaz o último commit descartando alterações (com confirmação em texto).
- **Descartar alterações**: Limpa arquivos modificados não commitados (`git restore` / `git clean`).
- **Stash**: Salvar, listar e restaurar alterações temporárias.

### 5. Gerenciar Branches
- Listar branches locais e remotas.
- Criar e alternar para nova branch.
- Trocar de branch ativa.
- Excluir branch local com segurança.

### 6. Configuração da Pasta do Servidor Bare
- Permite alterar o caminho da pasta central de repositórios bare (padrão: `~/git-bare-hub`).
- Configuração persistida automaticamente em `~/.config/gitbare/config`.
