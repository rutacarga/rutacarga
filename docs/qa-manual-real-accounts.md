# Plan de QA manual — RUTA CARGA

- Rama: feature/roadmap-inteligencia-etapas
- Estado: matriz preparada; pruebas E2E con cuentas reales aún no ejecutadas
- Objetivo: validar los flujos de conductor/propietario, empresa y administrador sin contaminar datos operativos.

## Precaución de entorno
El preview Vercel se construye desde la rama de desarrollo, pero la aplicación utiliza el proyecto Supabase configurado en el frontend. Antes de crear solicitudes, publicar cargas, enviar verificaciones o cambiar estados desde el preview, confirmar que apunta a un proyecto Supabase de staging con datos aislados. No asumir que un preview implica una base de datos de pruebas. Hasta disponer de staging, limitar las pruebas a navegación y lecturas no destructivas.

## Perfiles y cobertura

### A. Visitante sin sesión
- Abrir home y navegar cargas publicadas.
- Filtrar por origen, destino, tipo y fecha; limpiar filtros.
- Abrir servicios complementarios y FAQ.
- Confirmar que no aparecen pestañas privadas de empresa, administración, notificaciones o solicitudes.
- Intentar abrir vistas privadas por navegación directa si existe ruta; confirmar rechazo visual y en consultas.

### B. Conductor / propietario verificado
- Iniciar sesión con cuenta de prueba autorizada.
- Revisar que aparezcan alertas inteligentes, perfil/vehículo y mis solicitudes.
- Verificar coincidencias y razones mostradas; confirmar que la pantalla explica que no garantiza compatibilidad.
- Comprobar notificaciones existentes y marcar una como leída solo en staging.
- En staging, crear una solicitud de interés y comprobar que la empresa dueña recibe notificación.
- En staging, confirmar que no puede publicar cargas ni modificar estados de solicitudes.

### C. Conductor no verificado
- Confirmar que puede explorar cargas.
- Confirmar que el flujo de interés/publicación queda bloqueado hasta verificar.
- Confirmar que la interfaz explica el requisito sin exponer documentos ni información privada.
- No subir documentos reales durante QA; usar documentos sintéticos en staging.

### D. Empresa transportadora verificada
- Confirmar acceso a publicar cargas y mis publicaciones.
- En staging, publicar carga de prueba y comprobar que aparece en búsqueda.
- Revisar solicitudes recibidas, historial y panel empresarial.
- Cambiar una solicitud de pending a contacted y luego closed según transiciones permitidas.
- Confirmar notificación al conductor y que el tiempo al primer contacto se calcula solo con historial real.
- Confirmar que la empresa no puede leer solicitudes de otra empresa.

### E. Empresa no verificada
- Confirmar que no puede publicar cargas ni cambiar estados.
- Confirmar que no puede leer solicitudes ajenas.
- No alterar estado de verificación para facilitar la prueba.

### F. Administrador
- Confirmar acceso al resumen operativo y herramientas administrativas autorizadas.
- Verificar que los indicadores muestran datos coherentes con la base de staging.
- Verificar que el tiempo mediano se oculta como muestra insuficiente con menos de cinco casos.
- En staging, probar acciones administrativas solo con cuentas y registros sintéticos.
- Confirmar que una sesión no administrativa no puede invocar RPC administrativas ni ver vistas de administración.

## Pruebas transversales
- Móvil Android: navegación, scroll, botones, formularios y teclado.
- Errores de red: estados de carga, mensajes claros y posibilidad de reintentar.
- Sesión expirada: vistas privadas bloqueadas y retorno seguro.
- Aislamiento: usuario A no accede a datos de usuario B; empresa A no accede a solicitudes de empresa B.
- Privacidad: no aparecen rutas de documentos, tokens, teléfonos ni datos sensibles en mensajes/alertas.
- Accesibilidad básica: labels, foco visible, contraste, aria-live en estados y navegación por teclado.

## Criterios de aprobación
- Ningún usuario puede saltarse verificación o rol.
- Ninguna empresa puede modificar solicitudes ajenas.
- Ningún conductor puede modificar estados administrados por la empresa.
- No hay errores JS no controlados ni consultas RLS inesperadas.
- Los indicadores no inventan métricas con muestra insuficiente.
- Las acciones de escritura se prueban exclusivamente en staging o con datos de prueba autorizados y reversibles.

## Registro de evidencia
Por cada caso registrar: fecha/hora, perfil, navegador/dispositivo, pasos, resultado esperado, resultado observado, captura sin datos personales y referencia del error. No copiar tokens, documentos ni datos de terceros en tickets.

## Hallazgos de aislamiento de entornos — 2026-11-11

Inspección de solo lectura de la configuración conectada:

- Supabase solo muestra el proyecto `RUTA CARGA` (`hnnjdtisekgacydcsvzd`) en la organización actual.
- La lista de ramas de desarrollo de ese proyecto está vacía.
- La organización Supabase está en plan Free.
- Vercel no devuelve variables de entorno configuradas para el proyecto `rutacarga`.
- El `index.html` de esta rama define directamente `SUPABASE_URL` con el host del proyecto `hnnjdtisekgacydcsvzd`; por tanto, el preview comparte backend con ese proyecto y NO constituye un entorno aislado.
- La clave pública/anon del cliente está embebida en el frontend, como corresponde a un cliente público; nunca debe sustituirse por una clave secreta o service_role.

### Decisión de QA

Hasta disponer de un proyecto Supabase de staging independiente:

1. Se permiten inspección de código, validación estática y navegación visual que no escriba datos.
2. No ejecutar desde preview altas, cambios de perfil, solicitudes de interés, publicaciones, verificaciones, cambios de estado, lectura de documentos privados ni acciones administrativas que puedan alterar datos.
3. No crear ramas/proyectos Supabase ni activar recursos con costo sin revisar primero el costo y obtener autorización específica.
4. Para habilitar E2E, configurar un backend de staging aislado y cuentas sintéticas por rol; después revisar que el frontend de preview apunte exclusivamente a ese backend antes de probar escrituras.
5. No solicitar contraseñas al usuario. Las sesiones de QA deben prepararse mediante el flujo de acceso normal y con cuentas de prueba autorizadas.

Este hallazgo bloquea pruebas E2E con escrituras; no bloquea el trabajo de revisión estática ni modifica producción.
