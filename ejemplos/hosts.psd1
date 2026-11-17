# EJEMPLO. El archivo real lo genera Extraer en config\hosts.psd1.
#
# Entradas: 'IP nombre'. Se anaden las que falten; nunca se borra ninguna.

@{
    Entradas = @(
        '192.168.1.10 nas.casa'
        '127.0.0.1 miapp.local'
    )
}
