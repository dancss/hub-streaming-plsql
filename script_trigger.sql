CREATE OR REPLACE TRIGGER trg_pos_assinatura_hub
AFTER INSERT ON assinaturas_cliente
FOR EACH ROW
BEGIN
    -- Dispara o processo de ativação HTTP para a assinatura recém criada
    pkg_integracao_hub.ativar_servicos_parceiros(:new.id_assinatura);
END;
/