# 🚀 Hub Streaming - Integração Legado-API com Oracle PL/SQL

## 📌 Cenário e Contexto Arquitetural
Em processos de modernização de ecossistemas corporativos (altamente comuns em indústrias verticais como as de Telecomunicações), a transição de arquiteturas monolíticas baseadas em dados para microsserviços exige estratégias de integração resilientes. 

Este projeto simula uma solução de **Event-Driven Integration** (Integração Baseada em Eventos) para um agregador de serviços de streaming (*Hub Streaming*, inspirado no modelo de canais embutidos do Amazon Prime). Quando uma nova assinatura é persistida na camada de dados, o banco de dados atua ativamente para notificar e provisionar os acessos em parceiros externos (como Disney+, Paramount+ ou Crunchyroll) consumindo microsserviços baseados em APIs REST modernas.

---

## 🛠️ Tecnologias e Recursos Utilizados
* **Database Engine:** Oracle Database Express Edition (XE) 18c.
* **Linguagem Procedural:** Oracle PL/SQL.
* **Mecanismos de Integração:** Pacote Nativo `UTL_HTTP`.
* **Formatos de Carga (Payload):** Manipulação nativa de estruturas JSON (`JSON_OBJECT`, `JSON_ARRAYAGG`, `JSON_QUERY`).
* **Automação:** Triggers de Banco de Dados de Linha (`AFTER INSERT FOR EACH ROW`).

---

## 🏗️ Estrutura do Repositório

O projeto está dividido em quatro scripts fundamentais organizados de forma incremental:

1.  **`script_main_tables.sql`**: Camada de persistência relacional. Implementa a modelagem de entidades (Clientes, Planos, Parceiros e Assinaturas) utilizando chaves primárias compostas, auto-incremento nativo (`IDENTITY`) e integridade referencial através de Constraints de chave estrangeira.
2.  **`script_packages.sql`**: O core técnico do projeto. Cria a especificação e o corpo da `Package` responsável por encapsular a lógica de negócio, extrair os dados relacionais transformando-os em payloads JSON complexos, gerenciar a sessão HTTP via `UTL_HTTP` (configurando headers, controle de timeouts e controle de vazamento de memória) e realizar a análise de status codes de resposta para o tratamento e auditoria de erros.
3.  **`script_trigger.sql`**: Gatilho automatizado responsável pelo desacoplamento da chamada de provisionamento. Garante que qualquer inserção bem-sucedida na tabela de assinaturas acione o ecossistema de integração assincronamente em relação à aplicação cliente.
4.  **`script_select_insert.sql`**: Dataset e massa de dados para testes locais, validações estruturais e simulação do pipeline completo.

---

## 🧠 Destaques Técnicos & Melhores Práticas Implementadas

* **Prevenção de Deadlocks e Gargalos:** Configuração explícita de `UTL_HTTP.set_transfer_timeout` fixado em 10 segundos para mitigar o risco de requisições externas presas travarem transações críticas de escrita no banco de dados.
* **Segurança de Conexão:** Tratamento robusto com blocos `EXCEPTION` dedicados para capturar falhas catastróficas de rede, garantindo o fechamento forçado da sessão de rede através de `UTL_HTTP.end_response`.
* **Manipulação Avançada de JSON:** Agrupamento de relacionamentos muitos-para-muitos (N:M) transformados nativamente em arrays JSON via banco usando `JSON_ARRAYAGG` para consumo direto por microsserviços, eliminando a necessidade de parseamento excessivo no backend.

---

## 🚀 Como Executar o Projeto Localmente

1.  Conecte-se ao seu Pluggable Database (ex: `XEPDB1`) com um usuário administrador ou que possua privilégios de criação de objetos (`CREATE TABLE`, `CREATE PROCEDURE`, `CREATE TRIGGER`).
2.  Execute os scripts respeitando a ordem de dependência:
    ```sql
    @script_main_tables.sql
    @script_packages.sql
    @script_trigger.sql
    ```
3.  Execute o script de teste para rodar o pipeline integrado:
    ```sql
    @script_select_insert.sql
    ```
4.  Monitore a alteração automática do campo `status_assinatura` de `PENDENTE` para `ATIVO` (ou falhas mapeadas de conexão) para comprovar o comportamento da integração.

---
*Desenvolvido como projeto de portfólio focado em Engenharia de Dados, Arquitetura de Banco de Dados e Integração de Sistemas Corporativos.*
