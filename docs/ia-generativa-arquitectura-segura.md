# ADR — Arquitectura segura para IA generativa en RUTA CARGA

- Estado: propuesta técnica, no implementada
- Fecha: 2026-11-12
- Alcance: asistente de orientación para conductores, propietarios y empresas

## Contexto
El asistente actual responde preguntas frecuentes mediante reglas deterministas en el navegador. La siguiente evolución aprobada conceptualmente es IA generativa, pero no hay autorización para activar un proveedor de pago, crear una cuenta externa ni usar datos personales en un modelo.

## Decisión propuesta
Cuando exista aprobación específica de proveedor, presupuesto y política de tratamiento de datos, implementar la inferencia exclusivamente del lado servidor (preferiblemente una Supabase Edge Function o una función server-side equivalente). El navegador nunca recibirá API keys ni credenciales privilegiadas.

## Flujo propuesto
1. El cliente envía el mensaje y un identificador de conversación opaco, autenticado con la sesión vigente.
2. La función valida JWT, rol, estado de cuenta, longitud y tipo de contenido; rechaza sesiones inválidas.
3. Aplica límites por usuario, rol e IP, cuotas diarias y protección contra abuso antes de llamar al modelo.
4. Clasifica la intención. Las preguntas frecuentes y hechos operativos simples siguen usando respuestas deterministas, sin coste de modelo.
5. Para preguntas que requieran generación, construye un contexto mínimo con información pública o autorizada para ese usuario. No consulta datos de terceros ni agrega documentos, teléfonos, WhatsApp, placas, NIT o identificadores personales al prompt por defecto.
6. Envía al proveedor únicamente el texto mínimo necesario, con instrucciones de que el contenido del usuario y cualquier documento recuperado son datos no confiables, nunca instrucciones del sistema.
7. Valida y limita la respuesta, elimina datos sensibles, registra métricas técnicas sin almacenar secretos ni contenido sensible y devuelve la respuesta.
8. Ante proveedor caído, cuota agotada, baja confianza o intención transaccional, responde con FAQ determinista o deriva al equipo humano.

## Límites de autoridad
El asistente puede explicar, resumir y orientar. No puede aprobar/rechazar usuarios, publicar o retirar cargas, cambiar estados, aceptar solicitudes, contactar terceros, negociar tarifas, reservar servicios, emitir cobros ni realizar pagos. Ninguna herramienta con capacidad de escritura se expone al modelo.

## Seguridad y privacidad obligatorias
- Mantener claves en secretos server-side; nunca usar variables públicas para credenciales de proveedor.
- Validar autorización en servidor; no confiar en roles, IDs ni claims editables enviados por el navegador.
- RLS sigue siendo la autoridad para lecturas de datos privados.
- Separar datos por usuario/empresa; impedir acceso cruzado (BOLA/IDOR).
- Sanitizar HTML y renderizar respuestas como texto, no como HTML ejecutable.
- Protección contra prompt injection: instrucciones del sistema inmutables, delimitación de contenido no confiable, sin navegación ni herramientas arbitrarias.
- Retención mínima, borrado y acceso a conversaciones definidos antes de activar el servicio.
- Consentimiento y aviso de privacidad adecuados al propósito; revisión jurídica colombiana antes de procesar datos personales.
- Logs con IDs técnicos, latencia, tokens/costo y códigos de error; nunca API keys, JWT, teléfonos, documentos ni prompts con datos sensibles.
- Interruptor de apagado global y por usuario/rol; fallback inmediato al asistente FAQ.

## Costos y control
- No se habilita proveedor hasta aprobar proveedor, modelo, precio por tokens, presupuesto mensual y límites de gasto.
- Definir máximo de tokens de entrada/salida, máximo de mensajes por usuario y rate limit.
- Cachear respuestas genéricas cuando sea seguro y evitar llamadas repetidas.
- Alertar al alcanzar 50%, 80% y 100% del presupuesto configurado.
- No cambiar el plan de Supabase ni contratar servicios adicionales sin autorización.

## Pruebas requeridas antes de activar
1. Sesiones válidas e inválidas; conductor, propietario, empresa y administrador.
2. Aislamiento entre empresas y entre usuarios.
3. Prompt injection directo e indirecto y contenido malicioso.
4. Intentos de obtener datos personales o información de otros usuarios.
5. Límites, concurrencia, cuota agotada, timeout y proveedor indisponible.
6. Verificar que el asistente no puede ejecutar acciones transaccionales.
7. Revisión de retención, consentimiento, costos y fallback.

## Fuera de alcance en esta decisión
No crear Edge Function, cuenta de proveedor, API key, integración, cobro, WhatsApp, correo, acceso a datos privados para el modelo ni herramientas de escritura. Este ADR documenta la arquitectura prevista y no activa ninguna integración.
