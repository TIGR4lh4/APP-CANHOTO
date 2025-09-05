from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import mysql.connector
import datetime
import os
import config
import logging
from ldap3 import Server, Connection, ALL

app = Flask(__name__)
CORS(app)

# ================= CONFIG UPLOAD =================
UPLOAD_FOLDER = r"C:\Users\bruno.guerra\Documents\appfotos"
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ================= LOGGING =================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("ldap.log", encoding="utf-8"),
        logging.StreamHandler()
    ]
)

# ================= CONEXÃO BANCO =================
def get_conn():
    return mysql.connector.connect(**config.DB_CONFIG)

# ================= CONFIG LDAP =================
LDAP_SERVER = "ldap://192.168.11.250"
LDAP_DOMAIN = "adds.local"

# ================= LOGIN =================
@app.route("/login", methods=["POST"])
def login():
    data = request.json
    username = data.get("email")
    password = data.get("password")

    if not username or not password:
        return jsonify({"error": "Credenciais não informadas"}), 400

    if username == "admin" and password == "admin":
        logging.info("✅ Login ADMIN local OK")
        salvar_login(username, "SUCESSO_ADMIN")
        return jsonify({
            "message": "Login realizado com sucesso (ADMIN local)",
            "user": {"username": username}
        }), 200

    try:
        user = username if "@" in username else f"{username}@{LDAP_DOMAIN}"
        server = Server(LDAP_SERVER, get_info=ALL)
        conn = Connection(
            server,
            user=user,
            password=password,
            authentication="SIMPLE",
            auto_bind=True
        )

        if conn.bound:
            logging.info(f"✅ Login LDAP OK - Usuário: {username}")
            salvar_login(username, "SUCESSO_LDAP")
            return jsonify({
                "message": "Login realizado com sucesso (LDAP)",
                "user": {"username": username}
            }), 200
        else:
            logging.warning(f"❌ Falha no bind LDAP - Usuário: {username}")
            salvar_login(username, "FALHA")
            return jsonify({"error": "Falha de autenticação LDAP"}), 401

    except Exception as e:
        logging.error(f"❌ Erro de conexão LDAP: {str(e)} - Usuário: {username}")
        salvar_login(username, "ERRO")
        return jsonify({"error": "Erro ao conectar no LDAP"}), 500

# ================= SALVAR LOGIN NO BANCO =================
def salvar_login(usuario, status):
    try:
        conn = get_conn()
        cursor = conn.cursor(buffered=True)
        cursor.execute("""
            INSERT INTO logins (usuario, status, datahora)
            VALUES (%s, %s, %s)
        """, (usuario, status, datetime.datetime.now()))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        logging.error(f"Erro ao salvar log no banco: {str(e)}")

# ================= LISTAR EMPRESAS =================
@app.route("/empresas", methods=["GET"])
def get_empresas():
    conn = get_conn()
    cursor = conn.cursor(dictionary=True, buffered=True)
    query = """
        SELECT 
            e.EmpresaId,
            e.EmpresaNomeInterno
        FROM empresa e
        WHERE e.EmpresaId IN (20, 22, 23, 24, 25)
    """
    cursor.execute(query)
    results = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(results), 200

# ================= BUSCAR NF POR EMPRESA =================
@app.route("/nf/<int:nf>/<int:empresa_id>", methods=["GET"])
def get_nf(nf, empresa_id):
    conn = get_conn()
    cursor = conn.cursor(dictionary=True, buffered=True)
    query = """
        SELECT 
            n.NFId,
            n.NFNro,
            n.NFSerie,
            n.NFDtCadastro,
            n.NFDtEmissao,
            n.stPessoaNFId,
            n.NFUsuarioCadastro,
            n.NFTipoNF,
            c.CanhotoNFId,
            c.CanhotoNFEmpresaNome,
            c.CanhotoNFDtCadastro,
            c.CanhotoNFClienteId,
            c.CanhotoNFClienteNome
        FROM nf n
        LEFT JOIN canhotonf c 
               ON c.CanhotoNFNFNro = n.NFNro
              AND c.CanhotoNFSerieNF = n.NFSerie
        WHERE n.NFNro = %s
          AND n.EmpresaFiscalId = %s
          AND n.NFTipoNF = 2
    """
    cursor.execute(query, (nf, empresa_id))
    result = cursor.fetchone()
    cursor.close()
    conn.close()

    if not result:
        return jsonify({"error": "NF não encontrada"}), 404

    result["DataRecebimento"] = datetime.date.today().strftime("%Y-%m-%d")
    return jsonify(result), 200

# ================= UPLOAD DE IMAGEM =================
@app.route("/upload", methods=["POST"])
def upload_file():
    if "file" not in request.files:
        return jsonify({"error": "Nenhum arquivo enviado"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "Arquivo inválido"}), 400

    filename = datetime.datetime.now().strftime("%Y%m%d%H%M%S_") + file.filename
    save_path = os.path.join(app.config["UPLOAD_FOLDER"], filename)
    file.save(save_path)

    file_url = f"http://localhost:5000/files/{filename}"

    responsavel = request.form.get("Responsavel", "")
    documento = request.form.get("Documento", "")
    nf_obs = request.form.get("NFObs", "")
    data_recebimento = request.form.get("DataRecebimento")
    usuario_nome = "APP"
    empresa_nome = "SOLAR99"

    nf_nro = request.form.get("NFNro")
    empresa_id = request.form.get("EmpresaId")

    if not nf_nro or not empresa_id:
        return jsonify({"error": "NFNro e EmpresaId são obrigatórios"}), 400

    try:
        conn = get_conn()
        cursor = conn.cursor(dictionary=True, buffered=True)

        cursor.execute("""
            SELECT 
                nf.NFSerie,
                nf.NFDtCadastro,
                nf.NFDtEmissao,
                nf.EmpresaFiscalId,
                nf.stPessoaNFId,
                pessoa.PessoaNomeRazao 
            FROM nf
            JOIN pessoa ON pessoa.PessoaId = nf.stPessoaNFId 
            WHERE NFNro = %s AND EmpresaFiscalId = %s
        """, (nf_nro, empresa_id))
        nf_row = cursor.fetchone()

        if not nf_row:
            return jsonify({"error": "NF não encontrada"}), 404

        nf_serie = nf_row["NFSerie"]
        dt_cadastro = nf_row["NFDtCadastro"]
        dt_emissao = nf_row["NFDtEmissao"]
        empresa_fiscal_id = nf_row["EmpresaFiscalId"]
        cliente_id = nf_row["stPessoaNFId"]
        cliente_nome = nf_row["PessoaNomeRazao"]

        cursor.execute("""
            INSERT INTO canhotonf (
                CanhotoNFURLS3,
                CanhotoNFNomeResponsavel,
                CanhotoNFDocumento,
                CanhotoNFObs,
                CanhotoNFNFNro,
                CanhotoNFSerieNF,
                CanhotoNFDtRecebimento,
                CanhotoNFDtCadastro,
                CanhotoNFDtEmissao,
                CanhotoNFEmpresaId,
                CanhotoNFClienteId,
                CanhotoNFClienteNome,
                CanhotoNFNomeUsuario,
                CanhotoNFEmpresaNome
            ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            file_url,
            responsavel,
            documento,
            nf_obs,
            nf_nro,
            nf_serie,
            data_recebimento,
            dt_cadastro,
            dt_emissao,
            empresa_fiscal_id,
            cliente_id,
            cliente_nome,
            usuario_nome,
            empresa_nome
        ))

        conn.commit()
        cursor.close()
        conn.close()

    except Exception as e:
        logging.error(f"❌ Erro ao salvar no banco: {str(e)}")
        return jsonify({"error": f"Erro ao salvar no banco: {str(e)}"}), 500

    return jsonify({
        "message": "Upload realizado com sucesso",
        "url": file_url
    }), 200

# ================= SALVAR NF (JSON) =================
@app.route("/nf/save", methods=["POST"])
def save_nf():
    data = request.get_json()

    nf_nro = data.get("NroNF")
    nf_serie = data.get("NFSerie")
    empresa_id = data.get("EmpresaId")
    responsavel = data.get("Responsavel", "")
    documento = data.get("Documento", "")
    nf_obs = data.get("NFObs", "")
    data_recebimento = data.get("DataRecebimento")
    imagem = data.get("Imagem")
    usuario_nome = "APP"
    empresa_nome = "SOLAR99"

    if not nf_nro or not empresa_id:
        return jsonify({"error": "NroNF e EmpresaId são obrigatórios"}), 400

    try:
        conn = get_conn()
        cursor = conn.cursor(dictionary=True, buffered=True)

        cursor.execute("""
            SELECT 
                nf.NFSerie,
                nf.NFDtCadastro,
                nf.NFDtEmissao,
                nf.EmpresaFiscalId,
                nf.stPessoaNFId,
                pessoa.PessoaNomeRazao 
            FROM nf
            JOIN pessoa ON pessoa.PessoaId = nf.stPessoaNFId 
            WHERE NFNro = %s AND EmpresaFiscalId = %s
        """, (nf_nro, empresa_id))
        nf_row = cursor.fetchone()

        if not nf_row:
            return jsonify({"error": "NF não encontrada"}), 404

        dt_cadastro = nf_row["NFDtCadastro"]
        dt_emissao = nf_row["NFDtEmissao"]
        empresa_fiscal_id = nf_row["EmpresaFiscalId"]
        cliente_id = nf_row["stPessoaNFId"]
        cliente_nome = nf_row["PessoaNomeRazao"]

        cursor.execute("""
            INSERT INTO canhotonf (
                CanhotoNFURLS3,
                CanhotoNFNomeResponsavel,
                CanhotoNFDocumento,
                CanhotoNFObs,
                CanhotoNFNFNro,
                CanhotoNFSerieNF,
                CanhotoNFDtRecebimento,
                CanhotoNFDtCadastro,
                CanhotoNFDtEmissao,
                CanhotoNFEmpresaId,
                CanhotoNFClienteId,
                CanhotoNFClienteNome,
                CanhotoNFNomeUsuario,
                CanhotoNFEmpresaNome
            ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            imagem,
            responsavel,
            documento,
            nf_obs,
            nf_nro,
            nf_serie,
            data_recebimento,
            dt_cadastro,
            dt_emissao,
            empresa_fiscal_id,
            cliente_id,
            cliente_nome,
            usuario_nome,
            empresa_nome
        ))

        conn.commit()
        cursor.close()
        conn.close()

    except Exception as e:
        logging.error(f"❌ Erro ao salvar NF: {str(e)}")
        return jsonify({"error": f"Erro ao salvar no banco: {str(e)}"}), 500

    return jsonify({"message": "✅ Canhoto salvo com sucesso!"}), 201

# ================= SERVIR ARQUIVOS =================
@app.route("/files/<path:filename>")
def serve_file(filename):
    return send_from_directory(app.config["UPLOAD_FOLDER"], filename)

# ================= MAIN =================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
