# Reporte Automático de Backups AWS

Sistema automatizado para generar reportes diarios de backups de AWS y enviarlos por email usando AWS Lambda, S3 y SES.

## 📋 Características

- ✅ Filtra backups por rangos de tiempo específicos:
  - **Día anterior**: Jobs finalizados después de las 07:00 AM
  - **Día actual**: Jobs finalizados entre 00:00 y 07:00 AM
- 📊 Genera reporte Excel con resumen y detalles
- 📧 Envía emails automáticos con el reporte adjunto
- 💾 Almacena reportes históricos en S3
- ⏰ Ejecución programada diaria
- 🏷️ Mapeo de Account IDs a nombres legibles

## 🏗️ Arquitectura

```
EventBridge Rule (Cron)
       ↓
Lambda Function
       ↓
   ┌───┴───┐
   ↓       ↓
  S3      SES
(Reports) (Email)
```

## 📦 Recursos Creados

- **Lambda Function**: Procesa backups y genera reportes
- **Lambda Layer**: Dependencias Python (openpyxl)
- **S3 Bucket**: Almacenamiento de reportes con lifecycle policies
- **IAM Role/Policy**: Permisos para Lambda
- **EventBridge Rule**: Programación diaria (7:15 AM Chile)
- **CloudWatch Logs**: Logs de ejecución (30 días retención)
- **SES Email Identities**: Verificación de emails

## 🚀 Despliegue

### Prerrequisitos

- Terraform >= 1.0
- AWS CLI configurado
- Python 3.11+ (para construir el layer)
- pip

### Paso 1: Configurar Variables

Edita `variables.tf` o crea un archivo `terraform.tfvars`:

```hcl
aws_region  = "us-east-1"
environment = "prod"

# Emails
from_email = "david.amaya@axity.com"
to_emails  = ["Luis.PerezR@axity.com"]
cc_emails  = []  # Opcional

# Mapeo de cuentas AWS
account_mapping = {
  "123456789012" = "No-SAP"
  "234567890123" = "Redes y seguridad"
  "345678901234" = "SAP"
}

# Programación (UTC)
# Por defecto: 7:15 AM Chile = 10:15 AM UTC
schedule_expression = "cron(15 10 * * ? *)"
```

### Paso 2: Desplegar Infraestructura

```bash
# Inicializar Terraform
terraform init

# Revisar plan
terraform plan

# Aplicar cambios
terraform apply
```

### Paso 3: Verificar Emails en SES

**⚠️ IMPORTANTE**: AWS SES requiere verificación de emails antes de poder enviar.

#### Opción A: Verificación Manual (Inmediata)

1. Ve a la consola de AWS SES
2. En "Verified identities", encontrarás los emails creados
3. Revisa la bandeja de entrada de cada email
4. Haz clic en el enlace de verificación

#### Opción B: Verificación Automática

Si tienes acceso programático a los buzones:

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

## 📁 Estructura del Reporte Excel

### Hoja 1: Resumen
- AccountName
- T. COMPLETED
- T. FAILED

### Hoja 2: Día Anterior (Detalle)
- BackupJobID
- Status
- AccountID
- AccountName
- ResourceName
- MessageCategory
- ResourceID
- ResourceType
- CreationTime

### Hoja 3: Día Actual (Detalle)
- Mismos campos que Hoja 2

## 🔧 Configuración Avanzada

### Cambiar Horario de Ejecución

```hcl
# Lunes a Viernes a las 8:00 AM Chile (11:00 AM UTC)
schedule_expression = "cron(0 11 ? * MON-FRI *)"

# Todos los días a las 6:00 AM Chile (9:00 AM UTC)
schedule_expression = "cron(0 9 * * ? *)"
```

### Agregar Más Destinatarios

```hcl
to_emails = [
  "Luis.PerezR@axity.com",
  "otro.usuario@axity.com"
]

cc_emails = [
  "felipe.ortiz@axity.com",
  "joel.vidal@axity.com"
]
```

### Modificar Mapeo de Cuentas

Edita directamente en `lambda_function.py`:

```python
ACCOUNT_MAPPING = {
    'tu-account-id-1': 'Nombre Cuenta 1',
    'tu-account-id-2': 'Nombre Cuenta 2',
    # ...
}
```

Luego re-aplica:

```bash
terraform apply
```

### Cambiar Retención de Reportes en S3

```hcl
s3_retention_days = 365  # 1 año
```

## 📊 Monitoreo

### Ver Logs en CloudWatch

```bash
# Tiempo real
aws logs tail /aws/lambda/backup-reporter-prod --follow

# Últimas 1 hora
aws logs tail /aws/lambda/backup-reporter-prod --since 1h
```

### Ver Reportes en S3

```bash
# Listar reportes
aws s3 ls s3://backup-reporter-reports-prod-ACCOUNT_ID/reports/ --recursive

# Descargar reporte específico
aws s3 cp s3://backup-reporter-reports-prod-ACCOUNT_ID/reports/2025/12/backup-report-2025-12-04.xlsx .
```

### Métricas de Lambda

```bash
# Ver invocaciones
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=backup-reporter-prod \
  --start-time 2025-12-01T00:00:00Z \
  --end-time 2025-12-05T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

## 🐛 Troubleshooting

### Email no se envía

1. **Verificar identidades SES**:
   ```bash
   aws ses get-identity-verification-attributes \
     --identities david.amaya@axity.com Luis.PerezR@axity.com \
     --region us-east-1
   ```

2. **Revisar límites de SES**:
   ```bash
   aws ses get-send-quota --region us-east-1
   ```

3. **Verificar logs de Lambda** para errores específicos

### No se generan backups en el reporte

- Verificar que los rangos de tiempo sean correctos
- Revisar que la cuenta tenga permisos para `backup:ListBackupJobs`
- Ejecutar el script original manualmente para verificar datos

### Error de permisos

```bash
# Verificar rol de Lambda
aws iam get-role --role-name backup-reporter-prod-role

# Verificar políticas adjuntas
aws iam list-role-policies --role-name backup-reporter-prod-role
```

## 🔐 Seguridad

- ✅ Bucket S3 con encriptación AES256
- ✅ Versionado habilitado en S3
- ✅ Acceso público bloqueado
- ✅ Principio de mínimo privilegio en IAM
- ✅ CloudWatch Logs con retención limitada
- ✅ SES en sandbox o producción según configuración

## 🗑️ Limpieza

Para eliminar todos los recursos:

```bash
# ADVERTENCIA: Esto eliminará el bucket S3 y todos los reportes
terraform destroy
```

Si quieres mantener los reportes:

```bash
# Primero, vaciar el bucket
aws s3 rm s3://backup-reporter-reports-prod-ACCOUNT_ID/ --recursive

# Luego destruir
terraform destroy
```

## 📝 Mantenimiento

### Actualizar Lambda

```bash
# Modificar lambda_function.py
# Luego aplicar cambios
terraform apply
```

### Actualizar Dependencias

```bash
# Editar requirements.txt
# Limpiar layer anterior
rm -rf layer/ lambda_layer.zip

# Re-aplicar
terraform apply
```

## 🔄 CI/CD (Opcional)

Ejemplo con GitHub Actions:

```yaml
name: Deploy Backup Reporter

on:
  push:
    branches: [main]
    paths:
      - 'reporte_backups/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: terraform init
        working-directory: reporte_backups
      
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: reporte_backups
```

## 📞 Soporte

Para preguntas o problemas:
- Revisar logs de CloudWatch
- Verificar configuración de SES
- Comprobar permisos IAM
- Contactar al equipo de infraestructura

## 📄 Licencia

Uso interno - Axity
