# EJEMPLO. El archivo real lo genera Extraer en config\office.psd1.
#
# Activo          : $false = no instalar Office.
# Arquitectura    : 64 | 32
# Canal           : Current | MonthlyEnterprise | SemiAnnual | CurrentPreview | BetaChannel
# Idiomas         : es-mx, es-es, en-us... o MatchOS (idioma de Windows).
# Productos       : Id del producto (O365HomePremRetail = Microsoft 365 Familia/Personal,
#                   O365ProPlusRetail = Apps para empresa, ProPlus2024Retail...).
#                   Excluir: Access, Excel, Groove, Lync, OneDrive, OneNote, Outlook,
#                   OutlookForWindows, PowerPoint, Publisher, Teams, Word, Bing.
# Actualizaciones : $true = Office se actualiza solo.
# Silencioso      : $true = sin ventanas; $false = muestra el progreso de instalacion.
# La activacion se hace a mano: abre Word e inicia sesion con la cuenta Microsoft.

@{
    Activo = $true
    Arquitectura = '64'
    Canal = 'Current'
    Idiomas = @(
        'es-es'
    )
    Productos = @(
        @{
            Id = 'O365HomePremRetail'
            Excluir = @(
                'Access'
                'Publisher'
                'Groove'
                'Lync'
            )
        }
    )
    Actualizaciones = $true
    Silencioso = $true
}
