# STUDY no celular

O `server.js` entrega o app (`index.html`) e a API (`/api/*`) no **mesmo endereço**. Quando a página é aberta por um domínio que não é `localhost`, o front chama a API nesse mesmo domínio. Em `localhost` ou no Live Server, continua usando `http://localhost:3000`, como antes.

Há dois jeitos de publicar:

| | Caminho A: ngrok | Caminho B: Render |
|---|---|---|
| Quando usar | Uso pessoal, PC ligado | Sempre disponível |
| Custo | Grátis (1 domínio estático) | Grátis (o serviço "dorme" sem uso) |
| Endereço | `https://<algo>.ngrok-free.app` | `https://<nome>.onrender.com` |
| Chaves ficam | No `.env` do PC | No painel do Render |

Nos dois casos, depois é preciso **autorizar o domínio no Google Cloud** (passo final, abaixo).

---

## Preparação comum

1. Instale o Node.js 20 ou mais novo (`node -v`).
2. Na pasta do projeto:
   ```bash
   npm ci --omit=dev
   ```
3. Copie `.env.example` para `.env` e preencha `GEMINI_API_KEY` e `YOUTUBE_API_KEY`.
   - Windows (PowerShell): `Copy-Item .env.example .env`
   - macOS/Linux: `cp .env.example .env`
4. Teste local: `npm start` e abra `http://localhost:3000/`. O status fica em `http://localhost:3000/api/health`.

> O `.env` nunca vai para o git (está no `.gitignore`) e nunca é servido pelo servidor (`/.env` dá 404).

---

## Caminho A: ngrok (PC ligado)

### 1. Instalar e conectar o ngrok (uma vez)

- **Windows:** `winget install ngrok.ngrok` (ou baixe em https://ngrok.com/download e coloque o `ngrok.exe` no PATH)
- **macOS:** `brew install ngrok`
- **Linux:** siga https://ngrok.com/download (pacote apt/snap ou binário)

Crie uma conta gratuita em https://dashboard.ngrok.com, copie o authtoken e rode:

```bash
ngrok config add-authtoken <SEU_AUTHTOKEN>
```

### 2. Pegar o domínio estático gratuito

No painel do ngrok, em **Domains**, reserve o domínio grátis (ex.: `algo-aleatorio.ngrok-free.app`). Ele não muda entre execuções, e é por isso que o Google aceita.

### 3. Configurar o `.env`

```ini
NGROK_DOMAIN=algo-aleatorio.ngrok-free.app
ALLOWED_ORIGINS=https://algo-aleatorio.ngrok-free.app
TRUST_PROXY=1
```

(O script já define `TRUST_PROXY=1` e, se `ALLOWED_ORIGINS` estiver vazio, `https://<NGROK_DOMAIN>`.)

### 4. Subir servidor + túnel

- **Windows (PowerShell):**
  ```powershell
  npm run celular
  # ou: .\scripts\celular.ps1 -Domain algo-aleatorio.ngrok-free.app
  ```
- **macOS/Linux:**
  ```bash
  chmod +x scripts/celular.sh   # só na primeira vez
  npm run celular:sh
  # ou: ./scripts/celular.sh algo-aleatorio.ngrok-free.app
  ```

O script sobe o `server.js` e abre o túnel. Para parar tudo, use **Ctrl+C**.

Comando manual equivalente, em dois terminais: `npm start` e `ngrok http --url=algo-aleatorio.ngrok-free.app 3000`. Em versões antigas do ngrok v3, a opção chama `--domain=` em vez de `--url=`.

> No plano gratuito, o ngrok mostra uma página de aviso ("You are about to visit…") na primeira visita de cada navegador. Toque em **Visit Site** uma vez e ela não aparece de novo.

---

## Caminho B: Render (sempre disponível)

1. Coloque o projeto num repositório GitHub (ou GitLab). Confira se o `.env` **não** foi junto (`git status` não deve listá-lo).
2. Em https://dashboard.render.com, crie um **New > Blueprint** e aponte para o repositório. O Render lê o `render.yaml`:
   - build: `npm ci --omit=dev`; start: `node server.js`; health check: `/api/health`
   - `PORT` é definido pelo próprio Render (o `server.js` já lê do ambiente)
   - `TRUST_PROXY=1` e os limites de requisição já vêm preenchidos
3. O Render pede os valores marcados `sync: false`:
   - `GEMINI_API_KEY` e `YOUTUBE_API_KEY`: suas chaves
   - `ALLOWED_ORIGINS`: `https://<nome-do-serviço>.onrender.com` (sem barra no fim). Se ainda não souber o nome, deixe em branco e preencha em **Environment** depois do primeiro deploy. Salvar faz um novo deploy.
4. Abra `https://<nome>.onrender.com/api/health` para conferir (`"gemini": true, "youtube": true`).

Observações do plano gratuito:
- O serviço dorme depois de ~15 min sem uso. A primeira abertura seguinte pode levar até ~1 min.
- O disco é temporário: o cache de IA (`.cache/`) some a cada deploy ou reinício. Funciona, só gera de novo.

---

## Passo final: autorizar o domínio no Google (login)

1. https://console.cloud.google.com > **APIs e serviços > Credenciais** > o ID do cliente OAuth do app (termina em `…apps.googleusercontent.com`, o mesmo de `GOOGLE_CLIENT_ID` no `index.html`).
2. Em **Origens JavaScript autorizadas**, adicione o domínio exatamente assim: `https://algo-aleatorio.ngrok-free.app` ou `https://<nome>.onrender.com`. Sem barra no fim e sem caminho. Salve. Pode levar alguns minutos para valer.
3. Se a **Tela de consentimento OAuth** estiver em modo **Teste**, adicione seu e-mail em **Usuários de teste**.
4. No celular, abra `https://<domínio>/` e toque em **Continuar com o Google**.

---

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| Google: `origin_mismatch` / "não autorizado" | Domínio não está em "Origens JavaScript autorizadas", tem `/` no fim, ou ainda não propagou |
| Login ok, mas jornadas/vídeos falham | `GEMINI_API_KEY`/`YOUTUBE_API_KEY` ausentes (veja `/api/health`) |
| Erro de CORS no console | `ALLOWED_ORIGINS` diferente do endereço aberto (http × https, barra no fim, outro domínio) |
| "Muitas requisições" para todo mundo junto | `TRUST_PROXY` não definido atrás do proxy |
| ngrok: "domain not found" / "not reserved" | `NGROK_DOMAIN` diferente do domínio reservado na sua conta |

---

## Riscos (URL pública)

Quem souber o endereço pode chamar `/api/*` direto e gastar a cota do Gemini e do YouTube. O backend **não** valida o login do Google: o front não guarda o token depois de recarregar a página, e isso é intencional. `ALLOWED_ORIGINS` só impede que *outros sites* usem a API pelo navegador. Não impede chamadas diretas (curl, scripts).

Mitigações simples, sem mudar o código:
- **Limites menores:** por exemplo `RATE_LIMIT_AI_PER_MIN=10` e `RATE_LIMIT_VIDEOS_PER_MIN=30` (uso pessoal raramente passa disso). O cache já evita gerar de novo o que foi pedido antes.
- **Não divulgar o domínio.** No ngrok, desligar o túnel quando não estiver usando.
- **Google Cloud > Faturamento > Orçamentos e alertas:** criar um orçamento com alerta por e-mail.
- **Cotas por chave:** em **APIs e serviços > [API] > Cotas**, baixar o limite diário/por minuto da Generative Language API e da YouTube Data API.
- **Restringir as chaves** (Credenciais > chave > Restrições de API) só à API que cada uma usa.
