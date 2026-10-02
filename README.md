# Juventude Tem Voz – CRJ Flexal

Quiz avaliativo do Circuito Formativo "Nada sobre nós, sem nós" (outubro de 2026), com a Memória Jovem do CRJ, foto opcional e comprovante de brinde.

- `index.html` – o site que os jovens abrem pelo QR Code.
- `painel.html` – o painel da equipe (login): quem participou, brinde, fotos, acerto por pergunta, exportar CSV. Endereço: `/painel`.
- `mural.html` – o mural automático da devolutiva (login): só quem autorizou, com fotos, para imprimir/salvar PDF, projetar em modo apresentação ou baixar as fotos em ZIP. Endereço: `/mural` (botão "Gerar mural" no painel).
- `totem.html` – o mural para tela touch (totem): convite, cardápio, memórias, fotos, ideias e números, só com toques. Volta sozinho ao início depois de 1min30 parado. Endereço: `/totem`. Um educador entra no painel uma vez no aparelho antes. Para sair, segure o canto de cima à esquerda por 3 segundos.
- `/telao` – o mesmo totem para uma TV sem touch: mostra um QR Code e um código de 4 letras; o celular do jovem vira o controle (`controle.html`), em tempo real pelo Supabase Realtime. O jovem não precisa de login.
- `config.js` – URL e chave **pública** do Supabase. Nunca coloque a chave secreta aqui.
- `supabase/schema.sql` – banco, função de envio, fotos e regras de acesso. Rodar uma vez no SQL Editor do Supabase.

## Trocar uma pergunta
As perguntas ficam em `index.html`, na lista `PERGUNTAS`. Se mudar qual é a resposta certa, mude também o `gabarito` em `supabase/schema.sql` e rode a função de novo no SQL Editor.

## Equipe no painel
No Supabase: Authentication > Sign In / Providers: desligue "Allow new users to sign up". Depois, em Authentication > Users, use "Add user" para cada educador (e-mail e senha).

## Endereços
- Site dos jovens: https://juventude-tem-voz.vercel.app
- Painel da equipe: https://juventude-tem-voz.vercel.app/painel
- Mural da devolutiva: https://juventude-tem-voz.vercel.app/mural
- Totem touch: https://juventude-tem-voz.vercel.app/totem
- Telão com controle pelo celular (TV): https://juventude-tem-voz.vercel.app/telao — o jovem lê o QR da TV e controla em https://juventude-tem-voz.vercel.app/controle

Cada envio para a pasta `main` deste repositório publica o site automaticamente na Vercel.
