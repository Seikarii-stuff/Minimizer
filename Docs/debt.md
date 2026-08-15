# Minimizer Technical Debt

- Reusar la logica de Threat.PlayerHasAggro con situation 3. Los tests actualmente fallan para situation 3 = true, sin embargo in-game parece funcionar. Revisar en un futuro si es necesario un ajuste en la logica o en los tests.

## Añadir hechizos faltantes por clase

Objetivo: completar `data/SpellData.lua` con spells faltantes por clase (interrupts, CDs ofensivos, CDs defensivos y CC masivo).

Pasos recomendados:

- Obtener la lista canon de spells por clase desde una fuente fiable (Base de datos de la guild, WeakAuras export, o `GetSpellInfo(id)` en cliente real).
- Añadir entradas en `data/SpellData.lua` usando el formato `{ id = <num>, name = "<Spell Name>" }` para facilitar la lectura y las pruebas.
- Mantener el orden de prioridad: poner primero los spells preferidos/rápidos y luego los alternativos; el código selecciona el primer spell conocido por el jugador.
- Ejecutar `lua tests/smoke_test.lua` en el entorno de desarrollo para verificar que no se rompen las selecciones automáticas y que los dropdowns muestran nombres.
- En cliente real, validar localización: preferir `name = GetSpellInfo(id)` o revisar que el `name` sea detectado por el UI en el idioma del cliente.

Notas:

- No hace falta reiniciar el addon para que la lista funcione en desarrollo (los tests usan el archivo directamente), pero en cliente real puede requerirse `/reload`.
- Evitar duplicados y mantener comentarios indicando la clase/token para facilitar revisiones posteriores.
