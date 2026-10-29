- training practice system idea #research
	- android app m3e flutter, sober, minimalistic, minimize cognitive and visual overload
	- app name: question practice
	- question and alternatives
		- space to enter reasoning/justification
		- shows answer
	- gives score in the end
	- select a word/phrase to get what is it given the context and topic, only definition
		- keeps memory of those selected as concepts lacked
		- api key, llm. es opcional, puede ser apagado en settings
			- puede ser alternativamente una búsqueda en línea, en settings
	- review section in the end when it asks questions so user analyses errors
		- goal: make error cards
			- for skipped cards
				- no generar tarjeta de error, y en el review, preguntar "qué faltó aquí?" opciones: concepto, otra pregunta
					- si apreta concepto, poner para que complete "Definition of [ [aquí que escriba] ]: [ [aquí que escriba, campo de input de texto] ]" y se añade la carta de concepto
					- si pone "otra pregunta", ponerle campos de input de texto para pregunta y respuesta, y añadir esa como anki card básica
			- error cards components
				- question (alresdy have)
				- wrong answer by user (already have)
				- right answer (already have)
				- bias (ask user "What was the flawed assumption in your reasoning?" while showing him the reasoning/justification he gave before)
				- vaccine (ask user "what do you need to know to prevent that error in the future?")
			- opción "Te despistaste o leíste rápido? [togle] No hacer carta" en el ejercicio
				- para evitar cartas tipo "bias: leí mal; vaccine: leer bien"
	- feedback and explanation after each question
	- each question has
		- prompt (question)
		- alternatives
		- right answer
		- explanation why is that right answer, and why each one of other alternatives are not
	- questions (practices) are imported in json format (or txt with json inside). there can be multiple practices inside of one, and it can have practice information such as practice name and description
	- topics have name, description and an optional priority
	- time is not taken, but there is a reminder when answering a question each 5m. it is, after 5m, 10m, 15m...
	- shuffle topics option in home menu
	- "review past errors", las preguntas que en el pasado hizo mal. pero, que solo salgan a partir de dos días después de haberlas hecho mal, para asegurar que de verdad las aprendió. cuando las haga bien, entonces eliminar de la lista de cartas en error actuales pero mantener en el historial el error por motivos estadísticos y de historial
	- flow
		- save practices in topics, add statistics per topic and progress view
		- practice starts
		- user solves and blablabla
		- all questions anwered, shows overall score and number of words/phrases asked and button "start error review"
		- reviews errors and answers questions, ends
		- view to download concepts lacked as anki cards and error cards for anki (5 fields) o importar directamente a anki via anki api
			- add option to review what's included before download, checkmark to delete
			- concepts lacked anki cards are  cloze, like this
				- Definition of {{c1::GCP}}: {{c2::Google(Cloud Platform)}}
	- ai reccomendations
		- Usar el paquete Drift en Flutter. Sus consultas reactivas (Streams) son perfectas para que las estadísticas por tema, el progreso y el contador de errores se actualicen solos en la UI sin tener que refrescar a mano.
		- Validación con JSON Schema (Draft 2020-12):
		  Antes de meter un JSON a la base de datos, pasarlo por un validador de esquema. Si el archivo del usuario viene roto (falta una coma, falta el campo right_answer), se rechaza en la entrada mostrando un error claro en vez de romper la app con un NullPointerException.  
		- Historial desacoplado:
		  Una tabla para Questions, otra para PracticeSessions y otra para ErrorQueue. Cuando superas un error tras 48h, se elimina de la cola activa (ErrorQueue), pero la sesión original y el histórico quedan intactos en las estadísticas.  
		- Uso del ContentProvider de AnkiDroid:
		  No generar archivos zip ni exportar .apkg en Flutter. Insertar directamente vía Android ContentResolver usando el contrato de AnkiDroid (com.ichi2.anki.provider).  
		- Detalles técnicos nativos a configurar:
		  Añadir el bloque <queries> en el AndroidManifest.xml (obligatorio para Android 11+ para que tu app pueda "ver" a AnkiDroid).  
		  Empaquetar los campos de las tarjetas usando el delimitador oficial de Anki: u001f.  
		  Lanzar el broadcast intent com.ichi2.anki.DO_SYNC al terminar la exportación para que AnkiDroid sincronice automáticamente con AnkiWeb en segundo plano.  
		- Reducción de fricción espacial (Feedback in-place):
		  Al responder, no cambiar de pantalla. En la misma vista donde estás, el input de tu razonamiento se bloquea y debajo de cada alternativa se expande sutilmente su explicación correspondiente (por qué la correcta es correcta y por qué los distractores fallan).  
		- Paleta tonal limpia (ColorScheme.fromSeed):
		  Cero sombras pesadas o divisiones agresivas de Material 2. Usar elevación tonal (cambios sutiles de color de superficie) para no fatigar la vista en sesiones largas de estudio.  
		- Sin cronómetros regresivos:
		  Solo el recordatorio sutil cada 5, 10, 15 minutos para evitar la carga extrínseca y la ansiedad.  
		- Enrutamiento simple en Settings:
		  Opción A (Con API Key / BYOK): Llamada HTTP ligera a OpenAI/Groq/Claude para que devuelva un JSON estricto: {"definition": "..."} en menos de 20 palabras dado el contexto.Opción B (Sin API Key): Un Intent de Android para buscar el término seleccionado en DuckDuckGo/Wikipedia en una pestaña personalizada de Chrome (Custom Tab) dentro de la app.  
		- Registro automático:
		  Toda palabra consultada se guarda automáticamente en la tabla temporal de "Conceptos faltantes" para la revisión final.  
	- idioma de la app y documentación: inglés por defecto
	-
