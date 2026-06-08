CREATE OR REPLACE PACKAGE pkg_integracao_hub AS
    PROCEDURE ativar_servicos_parceiros(p_id_assinatura IN NUMBER);
END pkg_integracao_hub;
/

CREATE OR REPLACE PACKAGE BODY pkg_integracao_hub AS

    PROCEDURE ativar_servicos_parceiros(p_id_assinatura IN NUMBER) IS
        -- Variáveis para controle do HTTP
        v_req          UTL_HTTP.req;
        v_resp         UTL_HTTP.resp;
        v_url          VARCHAR2(255) := 'https://api.mock.hubstreaming.com/v1/webhook/provisioning';
        v_json_payload VARCHAR2(4000);
        v_response_text VARCHAR2(4000);
        
        -- Variáveis de controle de dados
        v_nome_cliente  assinaturas_cliente.nome_cliente%TYPE;
        v_email_cliente assinaturas_cliente.email_cliente%TYPE;
        v_nome_plano    planos.nome_plano%TYPE;
        v_lista_parceiros VARCHAR2(1000);
        
    BEGIN
        -- 1. Coleta os dados da assinatura e do plano usando um JOIN encadeado
        SELECT a.nome_cliente, a.email_cliente, p.nome_plano
          INTO v_nome_cliente, v_email_cliente, v_nome_plano
          FROM assinaturas_cliente a
          JOIN planos p ON a.id_plan = p.id_plan
         WHERE a.id_assinatura = p_id_assinatura;

        -- 2. Agrupa os parceiros embutidos em formato JSON Array (Disponível a partir do Oracle 12c+)
        SELECT JSON_ARRAYAGG(pa.nome_servico RETURNING VARCHAR2)
          INTO v_lista_parceiros
          FROM plano_parceiros pp
          JOIN parceiros pa ON pp.id_parceiro = pa.id_parceiro
         WHERE pp.id_plan = (SELECT id_plan FROM assinaturas_cliente WHERE id_assinatura = p_id_assinatura);

        -- 3. Monta o Payload JSON final que o microsserviço espera
        v_json_payload := JSON_OBJECT(
                            'id_assinatura' VALUE p_id_assinatura,
                            'cliente'       VALUE v_nome_cliente,
                            'email'         VALUE v_email_cliente,
                            'plano_contratado' VALUE v_nome_plano,
                            'parceiros_ativar' VALUE JSON_QUERY(v_lista_parceiros, '$')
                          );

        -- 4. Inicia a requisição HTTP POST
        v_req := UTL_HTTP.begin_request(v_url, 'POST', 'HTTP/1.1');
        
        -- Configuração dos Headers (Essencial para APIs REST modernas)
        UTL_HTTP.set_header(v_req, 'Content-Type', 'application/json');
        UTL_HTTP.set_header(v_req, 'Content-Length', LENGTH(v_json_payload));
        UTL_HTTP.set_header(v_req, 'Authorization', 'Bearer token_secreto_do_hub_2026');
        UTL_HTTP.set_transfer_timeout(v_req, 10); -- Timeout de 10 segundos para não travar o banco

        -- Envia o corpo do JSON
        UTL_HTTP.write_text(v_req, v_json_payload);

        -- 5. Recebe e trata a resposta da API externa
        v_resp := UTL_HTTP.get_response(v_req);

        -- Se o status for 200 (OK) ou 201 (Created), atualiza o status na tabela
        IF v_resp.status_code IN (200, 201) THEN
            UPDATE assinaturas_cliente
               SET status_assinatura = 'ATIVO'
             WHERE id_assinatura = p_id_assinatura;
        ELSE
            -- Se a API externa falhar, marca como erro para auditoria
            UPDATE assinaturas_cliente
               SET status_assinatura = 'ERRO_INTEGRACAO'
             WHERE id_assinatura = p_id_assinatura;
        END IF;

        -- Fecha a conexão HTTP (Boa prática crítica para evitar vazamento de memória/sessões)
        UTL_HTTP.end_response(v_resp);
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Tratamento de exceção genérica para capturar falhas de rede/timeout
            UPDATE assinaturas_cliente
               SET status_assinatura = 'FALHA_CONEXAO'
             WHERE id_assinatura = p_id_assinatura;
            
            -- Garante que a resposta feche mesmo em caso de erro grave catastrófico
            -- UTL_HTTP.end_response(v_resp);
    END Ativar_servicos_parceiros;

END pkg_integracao_hub;
/