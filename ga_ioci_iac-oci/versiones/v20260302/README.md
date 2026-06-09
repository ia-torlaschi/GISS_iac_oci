---

# 🏗 OCI Landing Zone – Terraform Local Deployment

## POC / MVP – Gestión desde entorno local (Windows)

---

# 📌 1. Objetivo

Este repositorio permite desplegar una **OCI Landing Zone (LZ)** utilizando:

* Terraform
* OCI CLI
* Módulo oficial `terraform-oci-modules-orchestrator`

El objetivo es gestionar la infraestructura como código desde entorno local, con posibilidad futura de migración a GitLab CI/CD corporativo.

---

# 🖥 2. Requisitos Previos

## 2.1 Terraform

Validar instalación:

```powershell
terraform -version
```

Recomendado:

* Terraform `>= 1.5.x`

---

## 2.2 OCI CLI

Validar instalación:

```powershell
oci --version
```

Configuración previa requerida:

```powershell
oci setup config
```

Archivo típico:

* `C:\Users\<usuario>\.oci\config`

Ejemplo de contenido:

```ini
[DEFAULT]
user=ocid1.user.oc19...
fingerprint=xx:xx:xx:xx
key_file=C:\Users\<usuario>\.oci\private_key.pem
tenancy=ocid1.tenancy.oc19...
region=eu-madrid-2
```

---

# 📂 3. Estructura de Directorios

Toda la operación se realiza bajo:

* `C:\oci-terraform\`

## 📁 Estructura utilizada

```
C:\oci-terraform
│
├── terraform-oci-modules-orchestrator   # Repositorio oficial (módulo base)
│
└── Giss-terraform                      # Root module del despliegue
    ├── main.tf
    ├── variables.tf
    ├── providers.tf
    ├── versions.tf
    ├── terraform.tfstate
    ├── oci-credentials.auto.tfvars.json
    ├── giss_governance__v3.2.json
    ├── giss_iam_v3.2.json
    └── giss_network_hub_b_empty_v3.2.json
```

---

# 🔁 4. Gestión del Repositorio Orchestrator

Repositorio oficial:

```text
https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator
```

## 4.1 Clonado inicial

```powershell
cd C:\oci-terraform
git clone https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator.git
```

## 4.2 Mantener actualizado

```powershell
cd C:\oci-terraform\terraform-oci-modules-orchestrator
git fetch
git pull origin main
```

## 4.3 Ver estado y versión

```powershell
git status
git log -1
```

---

# 🔁 5. Gestión del Repositorio Local (Giss-terraform)

## 5.1 Inicializar Git

```powershell
cd C:\oci-terraform\Giss-terraform
git init
```

## 5.2 Primer commit

```powershell
git add .
git commit -m "Initial Landing Zone deployment configuration"
```

## 5.3 Actualizar cambios

```powershell
git add .
git commit -m "Update configuration"
git push origin main
```

---

## 5.4 `.gitignore` recomendado

Crear/actualizar archivo `.gitignore`:

```
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.pem
*.auto.tfvars.json
tfplan
tfplan.txt
tfplan.json
```

---

# 🚀 6. Flujo Operativo Terraform (Orden Correcto)

## 6.1 Ubicación

```powershell
cd C:\oci-terraform\Giss-terraform
```

## 6.2 Limpieza controlada (si es necesario)

```powershell
Remove-Item -Recurse -Force .\.terraform
Remove-Item -Force .\.terraform.lock.hcl
```

> No borrar: `terraform.tfstate` ni los `*.json`.

## 6.3 Inicialización

```powershell
terraform init -upgrade -reconfigure
```

## 6.4 Formateo

```powershell
terraform fmt -recursive
```

## 6.5 Validación

```powershell
terraform validate
```

## 6.6 Generar Plan Congelado

```powershell
terraform plan `
  -var-file .\oci-credentials.auto.tfvars.json `
  -var-file .\giss_governance__v3.2.json `
  -var-file .\giss_iam_v3.2.json `
  -var-file .\giss_network_hub_b_empty_v3.2.json `
  -out tfplan
```

## 6.7 Exportar Plan para Auditoría

```powershell
terraform show tfplan > tfplan.txt
```

Alternativa JSON:

```powershell
terraform show -json tfplan > tfplan.json
```

## 6.8 Aplicar exactamente el plan

```powershell
terraform apply tfplan
```

---

# 🔎 7. Verificaciones OCI (CLI)

## 7.1 Listar compartments

```powershell
oci iam compartment list
```

## 7.2 Inventario completo de recursos

```powershell
oci search resource structured-search --query-text "query all resources" --output table
```

---

# 🌐 8. Validación DNS Identity Domains

```powershell
Resolve-DnsName <identity-domain>.identity.oci.oraclecloud.eu
```

```powershell
nslookup <identity-domain>.identity.oci.oraclecloud.eu 8.8.8.8
```

---

# 📦 9. Estado Terraform

## 9.1 Ver outputs

```powershell
terraform output
```

## 9.2 Exportar “show” del state (si se necesita)

```powershell
terraform show > terraform-show.txt
```

---

# 🔐 10. Seguridad

## 10.1 No versionar jamás

* `terraform.tfstate*`
* `*.pem`
* `oci-credentials.auto.tfvars.json`
* `tfplan*`

## 10.2 Recomendaciones enterprise

* Backend remoto con locking (GitLab State o OCI Object Storage)
* Separación **plan/apply**
* Branch protections + approvals
* Variables protegidas/masked en CI

---

# 🔄 11. Futuro: Migración a GitLab CI/CD

Pipeline recomendado:

1. `terraform fmt`
2. `terraform validate`
3. `terraform plan -out=tfplan`
4. Revisión manual / aprobación
5. `terraform apply tfplan`

Backend sugerido:

* GitLab Managed Terraform State
* OCI Object Storage (alternativa)

---

# 📌 12. Buenas Prácticas Enterprise

* Separar entornos (dev/test/prod)
* Versionar módulos y providers
* No hardcodear OCIDs en `.tf`
* Variables tipadas + `terraform validate`
* Logs/Audit habilitados en OCI
* Control de cambios por Pull Request

---

# 🧭 13. Estado Actual del Proyecto

✔ Terraform funcionando
✔ OCI CLI validado
✔ Orchestrator operativo
✔ Plan consistente
✔ Sin destrucciones pendientes
✔ Listo para CI/CD

---

# 📞 14. Soporte / Diagnóstico rápido

En caso de error:

```powershell
terraform providers
terraform version
oci --version
```

Revisar además:

* credenciales OCI (fingerprint/user/key)
* permisos IAM
* conectividad/DNS para Identity Domains

---

# ➕ 15. Extra: SDK oficial Oracle (consultas y troubleshooting)

Repositorio oficial:

```text
https://github.com/oracle/oci-python-sdk
```

## 15.1 Clonado inicial

```powershell
cd C:\oci-terraform
git clone https://github.com/oracle/oci-python-sdk.git
```

## 15.2 Mantener actualizado

```powershell
cd C:\oci-terraform\oci-python-sdk
git fetch
git pull origin main
```

## 4.3 Ver estado y versión

```powershell
git status
git log -1
```

Repositorio de ejemplos del **SDK oficial OCI para Python** (útil para validaciones, consultas y debugging de autenticación/servicios):

```text
https://github.com/oracle/oci-python-sdk/tree/master/examples/showoci
```

```powershell
cd C:\oci-terraform
cd .\oci-python-sdk\examples\showoci\

```

Usos típicos:

* Verificar autenticación fuera de Terraform
* Listar recursos/servicios y comparar contra Terraform/OCI CLI
* Diagnóstico de endpoints y permisos

---
