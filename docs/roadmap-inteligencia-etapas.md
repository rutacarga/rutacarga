# RUTA CARGA — Plan de implementación por etapas
Fecha: 2026-11-11
Estado: ideas aprobadas para preparación e implementación gradual.
Rama de trabajo: `feature/roadmap-inteligencia-etapas`

## Principios de despliegue
- No modificar ni sustituir los flujos productivos actuales de acceso Google, selección de rol, verificación, publicación de cargas, registro de interés ni estados.
- Construir cada capacidad en módulos aislados, detrás de una bandera de función y con apagado inmediato.
- No activar integraciones de pago, mensajería externa, geolocalización de precisión ni IA con datos personales sin configuración, aviso de privacidad, consentimiento y revisión de costos.
- La IA solo informa, resume y propone. No aprueba cuentas, cambia estados, negocia tarifas, compromete pagos ni cierra acuerdos.
- Toda escritura nueva debe ser autenticada, autorizada por RLS y registrada; nunca exponer claves secretas en el navegador.
- Hacer pruebas con datos de prueba y usuarios de prueba; no simular aprobaciones ni alterar registros reales.

## Endurecimiento de seguridad ya aplicado en Supabase
- Se movieron las implementaciones privilegiadas de `is_ruta_carga_admin`, `is_ruta_carga_verified_admin` y `empresa_ruta_carga_verificada` al esquema `private`, fuera del esquema público expuesto por PostgREST.
- Se conservaron funciones wrapper en `public` como `SECURITY INVOKER` para no romper las políticas RLS ni las comprobaciones del frontend.
- Se mantuvieron los permisos mínimos de ejecución necesarios para las políticas RLS; el helper de administrador devuelve false para un usuario anónimo/no administrador.
- La advertencia genérica de SECURITY DEFINER bajó de 15 a 12 funciones expuestas. Las 12 restantes son endpoints de operación que deben seguir siendo ejecutables por usuarios autenticados, pero validan rol/propiedad/estado dentro de la función. No se revocaron permisos necesarios.
- Se probaron con JWT sintético no administrador 11 RPC mutadoras (aprobación/rechazo, administración de cargas/empresas, cambios de estado y envío de verificaciones); todas rechazaron el intento. Las pruebas se ejecutaron en transacción y se revirtió.
- La protección contra contraseñas filtradas no se pudo activar en el plan Free: Supabase documenta que requiere Pro o superior. No se cambió el plan ni se generó un costo. Referencia: https://supabase.com/docs/guides/auth/password-security

## Estado técnico de partida
- Frontend actual: aplicación HTML/JavaScript en `index.html`, Supabase JS desde el navegador y despliegue Vercel.
- Tablas existentes relevantes: `profiles`, `vehicles`, `company_loads`, `load_interest_requests`, `company_public_contacts`, verificaciones e historiales.
- RLS está habilitado en las tablas públicas existentes. Los flujos de verificación y cambios de estado tienen controles y triggers existentes.
- No hay Edge Functions de Supabase desplegadas actualmente.
- Los vehículos guardan configuración, carrocería, ciudad y disponibilidad; las cargas guardan origen, destino, tipo de carga, vehículo requerido, fecha y pago.
- El flujo actual no usa carga de documentos desde el frontend. No asumir que existen consentimientos de marketing, notificaciones ni permisos de WhatsApp.
- El panel administrativo ya consulta verificaciones, usuarios, cargas, solicitudes e historiales; el panel de empresa ya lista publicaciones e interesados.

## Avance de la primera etapa en preview
- Emparejamiento de cargas: primera versión de reglas en frontend, sin escrituras ni servicios externos. La puntuación representa coincidencias confirmadas sobre 100 y advierte que no usa GPS ni valida el tipo exacto del vehículo.
- Panel empresarial: añade total de solicitudes y tasa de contacto a los indicadores existentes.
- Administrador IA inicial: panel de resumen operativo en solo lectura, con conteos de pendientes y recomendaciones basadas en reglas. No ejecuta acciones ni utiliza todavía un modelo generativo.
- La rama de preview se despliega como preview independiente; la producción no se ha actualizado con estos cambios de interfaz.
- Validación técnica: JavaScript pasó comprobación sintáctica. El despliegue Vercel de la rama está en estado READY. Aún falta la prueba de interacción real con cuentas de conductor, empresa y administrador.

## Etapas y dependencias

### Etapa 0 — Base segura y observabilidad (sin cambios visibles en producción)
1. Definir catálogo de eventos de negocio y contratos de datos.
2. Preparar tablas nuevas aisladas para notificaciones/eventos y preferencias, con RLS restrictivo y sin acceso anónimo.
3. Diseñar deduplicación, expiración, reintentos y trazabilidad antes de conectar disparadores.
4. Añadir banderas de función para poder activar/desactivar módulos.
5. Preparar datos de prueba y checklist de regresión.

Dependencias: ninguna integración externa.  
Costo incremental previsto: cero si cabe en cuotas actuales; puede aumentar consumo de base de datos/almacenamiento. No se crea otro proyecto ni se cambia el plan.  
Riesgo: bajo si las tablas quedan aisladas y no se conectan todavía a los flujos actuales.

### Etapa 1 — Emparejamiento inteligente + Panel empresarial + Administrador IA inicial
- Empezar con reglas deterministas, explicables y basadas en datos existentes: tipo de vehículo, configuración, carrocería, ciudad, origen/destino, fecha y disponibilidad.
- Mostrar por qué se recomienda una carga; nunca presentar un porcentaje como garantía de compatibilidad.
- Panel de empresa con métricas derivadas de sus propias publicaciones e intereses, filtradas por usuario.
- Administrador IA inicial en modo analítico: resumen de pendientes, actividad y anomalías; sin ejecutar acciones.
- No llamar a un modelo de IA para cálculos que pueden resolverse con reglas SQL/JavaScript.

Dependencias: normalización de catálogos de vehículos/cargas y reglas de acceso existentes.  
Costo incremental previsto: bajo o nulo en fase determinista; mayor consumo de consultas.  
Riesgo: bajo-medio; probar con cuentas de conductor y empresa de prueba y comparar contra resultados manuales.

### Etapa 2 — Alertas inteligentes dentro de la plataforma
- Notificaciones internas para nuevas cargas compatibles, solicitudes de interés, respuestas de empresas y vencimientos.
- Bandeja de notificaciones con leído/no leído y preferencias por usuario.
- Cola de eventos con idempotencia, reintentos limitados y registro de entrega.
- Empezar dentro de la plataforma; no enviar WhatsApp ni correos automáticamente todavía.

Dependencias: Etapa 0 y eventos de Etapa 1.  
Costo incremental previsto: bajo-medio, según volumen y frecuencia de consultas.  
Riesgo: medio; evitar duplicados, spam y revelar datos a usuarios no autorizados.

### Etapa 3 — Rutas, ubicación y cargas de retorno
- Primera versión: rutas por ciudades seleccionadas manualmente y detección de cargas en sentido inverso.
- Segunda versión: coordenadas y distancias estimadas solo cuando exista proveedor de geocodificación/rutas elegido.
- Mantener ciudad como alternativa cuando no haya coordenadas; no exigir ubicación precisa al usuario.

Dependencias: campos normalizados de origen/destino y vehículos, además de Etapa 1.  
Costo incremental previsto: nulo con rutas manuales; variable si se contrata geocodificación/mapas por uso.  
Riesgo: medio; las distancias y tiempos deben etiquetarse como estimaciones.

### Etapa 4 — Perfil de confianza
- Señales verificables: estado de verificación, antigüedad, datos completos y cumplimiento de reglas de la plataforma.
- Reputación basada en interacciones verificadas y criterios publicados, no en rumores ni datos sensibles.
- Mecanismo de disputa, corrección y apelación antes de mostrar puntuaciones públicas.

Dependencias: política de reputación, evidencia verificable y proceso de reclamación.  
Costo incremental previsto: bajo-medio.  
Riesgo: alto en reputación/daño injustificado; no publicar puntajes hasta validar reglas y apelación.

### Etapa 5 — Servicios complementarios
- Directorio separado de talleres, llantas, combustible, seguros y proveedores.
- Alta manual y verificación básica del proveedor antes de publicar.
- No compartir datos de conductores con proveedores sin consentimiento explícito.

Dependencias: criterios de verificación, categorías, moderación y política de datos.  
Costo incremental previsto: bajo inicialmente; puede aumentar con moderación y promoción.  
Riesgo: medio; controlar suplantación, publicidad engañosa y recomendaciones no verificadas.

### Etapa 6 — Empresas Premium y Cargas destacadas
- Definir beneficios, límites, precios, facturación, cancelaciones y soporte antes de cobrar.
- Implementar primero un modo de prueba/sandbox y controles de elegibilidad.
- Separar el pago de la verificación: pagar no otorga verificación ni privilegios de seguridad.
- Registrar compras, vigencias, renovaciones y reembolsos con trazabilidad.

Dependencias: métricas de Etapa 1, confianza de Etapa 4, términos comerciales y proveedor de pagos aprobado.  
Costo incremental previsto: comisiones del proveedor de pagos y posibles costos de facturación/impuestos.  
Riesgo: alto por cobros; no activar cobros reales sin aprobación explícita de tarifas, proveedor y condiciones.

### Etapa 7 — Asistente IA 24/7
- Primero asistente dentro de RUTA CARGA, con respuestas a preguntas frecuentes y consultas de solo lectura.
- Respuestas transaccionales deterministas para confirmaciones; IA solo redacta/explica con datos autorizados.
- Escalamiento a humano ante dudas, disputas, datos faltantes o baja confianza.
- WhatsApp Business y correo se habilitan solo después de conectar cuentas oficiales, verificar plantillas, consentimientos, costos y políticas de retención.
- No permitir a la IA aprobar/rechazar usuarios, modificar cargas, aceptar solicitudes, negociar pagos ni cambiar estados.

Dependencias: Etapas 0 y 2, política de privacidad y retención, proveedor/modelo aprobado, monitoreo y presupuesto.  
Costo incremental previsto: consumo de modelo por tokens, invocaciones de funciones y, en su caso, cargos de WhatsApp/email.  
Riesgo: alto por alucinaciones y exposición de datos; limitar herramientas, registrar respuestas y probar ataques de prompt injection.

## Dependencias transversales y bloqueos
- Privacidad: antes de alertas externas, IA conversacional, reputación pública o directorios, completar política de tratamiento de datos, finalidades, canales de atención, retención y consentimiento conforme a la normativa colombiana aplicable. Los datos de contacto de transportadores son personales.
- Catálogos: normalizar tipos de vehículo, configuraciones, carrocerías, tipos de carga y ciudades sin romper los valores históricos.
- Seguridad: no confiar en roles guardados en el navegador ni en `user_metadata`; validar permisos en servidor/RLS.
- Integraciones: no crear cuentas pagas ni activar facturación/API externa sin autorización específica.
- Operación: cada módulo tendrá métricas, logs sin secretos, límites de frecuencia, manejo de fallos y botón de apagado.

## Criterios de salida de cada etapa
1. Pruebas de acceso por rol (conductor, empresa, administrador y usuario no autorizado).
2. Pruebas de aislamiento entre empresas y entre conductores.
3. Pruebas de regresión de acceso, verificación, publicación, interés y cambio de estado.
4. Verificación de logs, errores, duplicados y límites de uso.
5. Despliegue primero en preview; promoción a producción solo después de revisar el resultado.

## Primer trabajo autorizado
Preparar la arquitectura y la primera versión determinista de emparejamiento en una rama de trabajo/preview, sin modificar datos productivos ni activar notificaciones externas. La lógica debe ser explicable y reversible; el despliegue productivo queda separado.


## Avance adicional — cimientos de alertas internas (2026-11-12 UTC)
- Se creó `public.user_notifications` con destinatario, tipo de evento, título/mensaje breve, referencia a la solicitud, fecha de creación y fecha de lectura.
- RLS está activo. Un usuario autenticado solo puede consultar sus propias notificaciones y actualizar únicamente `read_at`; no puede insertar, borrar ni modificar el contenido. `anon` no tiene acceso.
- Los triggers internos generan una notificación a la empresa cuando recibe una solicitud de interés y al transportador cuando la empresa cambia el estado a `contacted` o `closed`.
- La función de trigger vive en el esquema `private`, es `SECURITY DEFINER` con `search_path` vacío y no es ejecutable directamente por `anon` ni por `authenticated`.
- Se añadieron índices para destinatario/fecha y para la clave foránea de solicitud.
- Verificación posterior: RLS habilitado; permisos comprobados (sin INSERT para authenticated, sin acceso anon, UPDATE limitado a `read_at`); dos triggers presentes; función privada sin EXECUTE público; asesor de rendimiento ya no reporta FK sin índice.
- **Todavía no hay bandeja visible en el frontend.** La tabla no se ha añadido a los esquemas expuestos del Data API ni se ha conectado al cliente; falta revisar la configuración de exposición, implementar UI y probar con cuentas de prueba. Por tanto, las alertas están preparadas a nivel de base de datos, pero no se presentan todavía a los usuarios.
- No se enviaron correos, WhatsApp ni mensajes externos, no se modificaron solicitudes reales y no se tocó producción del frontend.


## Avance — bandeja de alertas y búsqueda manual de regreso (2026-11-12 UTC)
- Se añadió una pestaña **Notificaciones** para cuentas autenticadas de todos los roles ya configurados. Consulta hasta 50 avisos recientes y muestra el contador de pendientes.
- La bandeja permite actualizar la lista y marcar avisos individuales como leídos. El frontend usa `textContent` para presentar títulos/mensajes y solo envía `read_at`; RLS y privilegios de columna siguen siendo la autoridad.
- La consulta usa exclusivamente la tabla `public.user_notifications`; no se añadió el esquema `private` a la API.
- Se habilitó **Carga de regreso** para conductores y propietarios, además de administradores. Usa búsqueda manual por ciudad sobre cargas publicadas; no solicita GPS, coordenadas ni proveedor externo.
- Pruebas de base de datos en transacciones revertidas: dos avisos de prueba para dos perfiles; un usuario autenticado solo pudo marcar como leída su propia fila (1 de 2). Prueba temporal de solicitud realista: el trigger creó el aviso para la empresa y, al cambiar a `contacted` como empresa propietaria verificada, creó el aviso para el transportador. Todo se revirtió; no quedaron datos de prueba.
- Frontend: el script JavaScript inline pasó comprobación sintáctica. No hay duplicados nuevos de IDs estáticos (el detector solo señaló una plantilla HTML dinámica preexistente). Aún falta prueba visual/interactiva con sesiones reales de conductor y empresa en navegador.
- El preview de Vercel se genera desde la rama; no se ha promovido a producción.


## Avance — perfil privado de confianza y servicios complementarios (2026-11-12 UTC)
- En la rama de preview se añadió **Mi perfil de confianza** dentro del perfil de cuenta. Muestra únicamente señales internas ya existentes: estado de verificación disponible según el rol y número de vehículos registrados.
- No calcula reputación, estrellas, puntajes, rankings ni historial público; no expone nombres, placas, teléfonos, documentos, NIT ni datos de terceros. El resumen está dentro del área autenticada de la cuenta.
- Se añadió la pestaña **Servicios complementarios** con categorías previstas (talleres, llantas/repuestos, grúas, parqueaderos, combustible y seguros), pero en estado informativo: no lista proveedores ni recomienda comercios todavía.
- El directorio permanecerá sin proveedores hasta definir criterios de validación, moderación, consentimiento y procedimiento para retirar o reportar un proveedor. No se habilitan pagos, reservas ni intercambio de datos con terceros.
- No se modificó el esquema de Supabase ni se cargaron datos comerciales. La UI se basa en información existente y muestra claramente que el directorio está en preparación.
- JavaScript inline validado sintácticamente tras los cambios. El detector de IDs solo señaló una plantilla dinámica preexistente; no se identificaron duplicados estáticos nuevos.
- La rama continúa aislada de producción. Falta prueba visual/interactiva con sesiones reales y revisión de contenido/privacidad antes de publicar.


## Avance — asistente de orientación 24/7 (2026-11-12 UTC)
- Se añadió en la rama de preview una pestaña **Asistente 24/7** con preguntas frecuentes sobre registro/roles, verificación, publicación, interés en cargas, carga de regreso, notificaciones, confianza y servicios complementarios.
- La primera versión es un orientador determinista con respuestas redactadas y coincidencia de palabras clave; **no es IA generativa ni un agente humano**. Se identifica de forma explícita para no crear expectativas falsas.
- Las respuestas se muestran con textContent; no se envían preguntas a proveedores externos ni se transmiten datos personales. No se conecta a LLM, WhatsApp, correo ni APIs de pago.
- No puede consultar estados privados, aprobar usuarios, modificar cargas, negociar tarifas ni efectuar pagos. Las consultas no reconocidas se derivan a las secciones correspondientes o al equipo de RUTA CARGA.
- JavaScript inline y unicidad de IDs estáticos comprobados después del cambio. Falta prueba interactiva con navegador y sesiones reales; sigue siendo preview aislado.
