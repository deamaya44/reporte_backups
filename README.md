# Reporte Automático de Backups AWS

Sistema Lambda que genera reportes diarios de backups multi-cuenta y los envía por email con Excel adjunto.

## Prerrequisitos

- AWS Backup configurado en todas las cuentas/subcuentas
- Cuenta principal con acceso cross-account a los datos de backups (AWS Organizations)
- Terraform y AWS CLI configurados

## Cómo Funciona

1. **EventBridge** ejecuta la Lambda diariamente a las 5:15 AM (Colombia)
2. **Lambda** consulta backups de todas las cuentas vía AWS Backup API:
   - Día anterior: jobs finalizados después de 07:00 AM
   - Día actual: jobs finalizados entre 00:00 - 07:00 AM
3. Genera Excel con 3 hojas: Resumen, Día Anterior, Día Actual
4. Guarda el reporte en **S3** y lo envía por **SES**

## Despliegue

### 1. Configurar Variables

Edita `locals.tf`:

```hcl
locals {
  from_email = "tu-email@dominio.com"
  to_emails  = ["destinatario@dominio.com"]
  cc_emails  = []  # Opcional

  schedule_expression = "cron(15 10 * * ? *)"  # 5:15 AM Colombia (UTC-5)
}
```

### 2. Aplicar Terraform

```bash
terraform init
terraform apply
```

### 3. Verificar Emails en SES

Revisa la bandeja de entrada de los emails y confirma la verificación (enlace que envía AWS SES).

```bash
# Listar identidades pendientes
aws ses list-identities --region us-east-1

# Reenviar verificación
aws ses verify-email-identity --email-address david.amaya@axity.com --region us-east-1
```

### Paso 4: Probar la Lambda

```bash
# Invocar manualmente
aws lambda invoke \
  --function-name backup-reporter-prod \
  --region us-east-1 \
  response.json

# Ver resultado
cat response.json

# Ver logs
aws logs tail /aws/lambda/backup-reporter-prod --follow
```

## 📧 Formato del Email

```
Subject: CAME - Reporte de Backups de Máquinas Virtuales AWS – Resumen 2025-12-04

Resumen del DÍA ANTERIOR (finalizados después de las 07:00 AM, 2025-12-03):
┌────────────────────┬──────────────┬───────────┐
│ AccountName        │ T. COMPLETED │ T. FAILED │
├────────────────────┼──────────────┼───────────┤
│ No-SAP            │ 46           │ 0         │
│ Redes y seguridad │ 1            │ 0         │
│ SAP               │ 26           │ 0         │
└────────────────────┴──────────────┴───────────┘

Resumen del DÍA ACTUAL (finalizados entre 00:00 y 07:00 AM, 2025-12-04):
[Tabla similar]

Se adjunta el reporte detallado en Excel.
```
## Estructura del Reporte Excel

### Hoja 1: Resumen
Consolidado total de ambos días con columnas:
- AccountName
- T. COMPLETED
- T. FAILED

### Hoja 2: Día Anterior
Detalle de backups finalizados después de 07:00 AM del día anterior

### Hoja 3: Día Actual  
Detalle de backups finalizados entre 00:00 - 07:00 AM del día actual

## Troubleshooting

**Email no llega**: Verifica que los emails estén verificados en AWS SES

**Hoja vacía**: Revisa los logs de CloudWatch para ver si se están obteniendo backups

**Error de permisos**: Asegúrate que la cuenta tenga acceso cross-account a AWS Organizations

## Limpieza

```bash
terraform destroy
```
