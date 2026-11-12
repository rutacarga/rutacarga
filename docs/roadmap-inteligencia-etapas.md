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
