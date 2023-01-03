--Tabela TMP de vendas (recebe novas linhas, SOURCE)

CREATE TABLE #tmp_fato_vendas 
(id_produto INT, 
id_cliente INT, 
id_data INT, 
unidades INT, 
valor DECIMAL(15, 2));

--Tabela fato de vendas (TARGET)

CREATE TABLE #fato_vendas 
(id_produto INT, 
id_cliente INT, 
id_data INT, 
unidades INT, 
valor DECIMAL(15, 2),
inativo INT, 
dt_modificacao DATETIME);

--Carga da tabela fato de vendas

INSERT INTO #fato_vendas
VALUES (1,1001,20221001,45,450,0,GETDATE()),
       (1,1002,20221001,5,50,0,GETDATE()),
       (2,1001,20221101,15,45,0,GETDATE()),
       (1,1002,20221101,50,150,0,GETDATE()),
       (1,1001,20221201,30,300,0,GETDATE()),
       (2,1002,20221201,50,150,0,GETDATE());

--Carga da tabela TMP de vendas (linhas excluídas da base, atualizadas e novas linhas)

INSERT INTO #tmp_fato_vendas
VALUES --(2,1001,20221101,15,45), --excluída
(1,1002,20221101,51,153), --atualizada
(1,1001,20221201,30,300), --mantida
--(2,1002,20221201,50,150), --excluída
(1,1001,20230101,16,48), --incluída
(1,1002,20230101,75,225); --incluída

SELECT*FROM #tmp_fato_vendas
SELECT*FROM #fato_vendas 


--Criando parâmetros para somente atualizar linhas dentro do intervalo que veio da origem (manter histórico que não sofre alterações fixo)
 
 DECLARE @dt_inicio INT = (SELECT MIN(id_data) FROM #tmp_fato_vendas) 
 DECLARE @dt_termino INT = (SELECT MAX(id_data) FROM #tmp_fato_vendas)
 
 --Comando MERGE para carga da tabela FATO

MERGE INTO #fato_vendas AS f_TARGET 
USING #tmp_fato_vendas AS f_SOURCE 
ON f_TARGET.id_produto = f_SOURCE.id_produto
AND f_TARGET.id_cliente = f_SOURCE.id_cliente
AND f_TARGET.id_data = f_SOURCE.id_data 
WHEN MATCHED
AND f_TARGET.unidades <> f_SOURCE.unidades OR f_TARGET.valor <> f_SOURCE.valor THEN --linhas existentes que tiveram modificação
UPDATE
SET f_TARGET.unidades = f_SOURCE.unidades,
    f_TARGET.valor = f_SOURCE.valor,
    f_TARGET.inativo = 0,
    f_TARGET.dt_modificacao = GETDATE() 
WHEN NOT MATCHED BY TARGET THEN -- linhas novas
INSERT (id_produto,
        id_cliente,
        id_data,
        unidades,
        valor,
        inativo,
        dt_modificacao)
VALUES
		(f_SOURCE.id_produto,
		f_SOURCE.id_cliente,
		f_SOURCE.id_data,
		f_SOURCE.unidades,
		f_SOURCE.valor,
		0,
		GETDATE())
		
WHEN NOT MATCHED BY SOURCE
AND f_TARGET.id_data BETWEEN @dt_inicio AND @dt_termino THEN --linhas existentes que foram apagadas da origem

UPDATE
SET f_TARGET.inativo = 1,
    f_TARGET.dt_modificacao = GETDATE();

GO 

--Criando view para retornar apenas linhas ativas (inativo = 0)

CREATE VIEW #vw_fato_vendas AS
SELECT id_produto,
       id_cliente,
       id_data,
       unidades,
       valor
FROM #fato_vendas
WHERE inativo = 0

