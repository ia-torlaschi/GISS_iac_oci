# ENS OCI PDF Sources

Guia portable para localizar el corpus PDF CCN-STIC-889 OCI sin depender de rutas absolutas.

## Prioridad de fuentes

1. Corpus interno del skill en references/pdf.
2. Adjuntos entregados por el usuario en la conversacion actual.
3. Directorios del workspace que coincidan con alguno de estos patrones:
   - **/CCN-STIC-889(OCI)/*.pdf
   - **/CCN-STIC-889*/**/*.pdf
   - **/2.Scripts_Interesantes/CCN-STIC-889(OCI)/*.pdf
4. Portal oficial ENS CCN-CERT cuando falte documentacion local.

## Corpus interno empaquetado

Ubicacion:
- references/pdf

Contenido base incluido:
- CCN-STIC-889-PERFIL-OCI-CAC.pdf
- CCN-STIC-889A-IAM-SEGURIDAD.pdf
- CCN-STIC-889B-MONITORIZACION-GESTION.pdf
- CCN-STIC-889C-ARQUITECTURAS-HIBRIDAS.pdf
- CCN-STIC-889D-OCI-DATABASE-VM.pdf
- CCN-STIC-889E-OCI-COMPUTE-VM-BAREMETAL.pdf
- CCN-STIC-889F-EXADATA-AUTONOMOUSDB.pdf
- CCN-STIC-889G-SAAS-PERFIL-CUMPLIMIENTO.pdf
- CCN-STIC-889H-SAAS-EPM-CONFIG-SEGURA.pdf
- CCN-STIC-889I-SAAS-FUSION-APPS-CONFIG-SEGURA.pdf
- CCN-STIC-889J-SAAS-FUSION-EPM-EURA.pdf
- CCN-STIC-889K-ROVING-EDGE-INFRA.pdf

## Indice rapido por codigo

| Codigo | Archivo corto | Dominio principal |
|---|---|---|
| 889 | CCN-STIC-889-PERFIL-OCI-CAC.pdf | Perfil de cumplimiento OCI C@C |
| 889A | CCN-STIC-889A-IAM-SEGURIDAD.pdf | IAM y servicios de seguridad |
| 889B | CCN-STIC-889B-MONITORIZACION-GESTION.pdf | Monitorizacion y gestion |
| 889C | CCN-STIC-889C-ARQUITECTURAS-HIBRIDAS.pdf | Arquitecturas hibridas |
| 889D | CCN-STIC-889D-OCI-DATABASE-VM.pdf | OCI Database en VM |
| 889E | CCN-STIC-889E-OCI-COMPUTE-VM-BAREMETAL.pdf | OCI Compute VM/Bare Metal |
| 889F | CCN-STIC-889F-EXADATA-AUTONOMOUSDB.pdf | Exadata y Autonomous DB |
| 889G | CCN-STIC-889G-SAAS-PERFIL-CUMPLIMIENTO.pdf | Perfil de cumplimiento Oracle Cloud SaaS |
| 889H | CCN-STIC-889H-SAAS-EPM-CONFIG-SEGURA.pdf | Configuracion segura Oracle SaaS EPM |
| 889I | CCN-STIC-889I-SAAS-FUSION-APPS-CONFIG-SEGURA.pdf | Configuracion segura Oracle SaaS Fusion Applications |
| 889J | CCN-STIC-889J-SAAS-FUSION-EPM-EURA.pdf | Oracle SaaS Fusion/EPM EURA |
| 889K | CCN-STIC-889K-ROVING-EDGE-INFRA.pdf | Roving Edge Infrastructure |

## Familia documental esperada

- Perfil de cumplimiento especifico Oracle Cloud OCI C@C.
- Guias de configuracion segura 889A, 889B, 889C...
- Anexos por servicio/plataforma (Compute, Database, Exadata, Hibrido, REI, SaaS, etc.).

## Regla de actualizacion continua

- Detectar automaticamente nuevos anexos 889 (por ejemplo 889L, 889M, etc.) por patron de nombre.
- No exigir mantenimiento manual del listado de PDFs en la skill.
- Si coexisten varias versiones, priorizar la mas reciente por fecha/metadata.

## Regla de trazabilidad

Cada recomendacion ENS->OCI debe citar al menos una fuente:
- PDF local (nombre de archivo)
- o URL oficial CCN-CERT
- y complementar con documentacion OCI cuando aplique implementacion tecnica.
