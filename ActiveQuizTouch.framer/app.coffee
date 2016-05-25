{TextLayer} = require 'TextLayer'

questionScrollComponent = new ScrollComponent
	width: Screen.width
	height: Screen.height

for questionNumber in [0..5]
	questionNumberHeight = 100
	questionNumberSpacing = 50
	new Layer
		parent: questionScrollComponent.content
		backgroundColor: "white"
		width: Screen.width
		height: questionNumberHeight
		y: questionNumber * (questionNumberHeight + questionNumberSpacing)
	
#==========================================
# Answer Input

answerBuffer =
	number: null
	sign: 1
answerLayer = new TextLayer
	x: 65
	y: 86
	width: 604
	height: 93
	fontSize: 48
	color: "red"
	backgroundColor: "yellow"
updatePendingNumber = (newAnswerBuffer) ->
	answerBuffer = newAnswerBuffer
	if newAnswerBuffer.number == 0
		answerLayer.text = if newAnswerBuffer.sign == 1 then "" else "-"
	else
		answerLayer.text = newAnswerBuffer.number * newAnswerBuffer.sign
updatePendingNumber
	number: 0
	sign: 1

#==========================================
# Keyboard

keyboardHeight = 432
keyboard = new Layer
	y: Screen.height - keyboardHeight
	width: Screen.width
	height: keyboardHeight
	backgroundColor: ""

keyWidth = Screen.width / 4
keyHeight = keyboardHeight / 4
keySpacing = 2

appendDigit = (digit) ->
	updatePendingNumber
		number: answerBuffer.number * 10 + digit
		sign: answerBuffer.sign
		
for column in [0..3]
	for row in [0..3]
		if row == 3 and column > 0
			# These keys are "eaten" by the big 0 and submit keys
			continue
		
		key = new Layer
			width: keyWidth - keySpacing
			height: keyHeight - keySpacing
			x: column * keyWidth
			y: row * keyHeight
			parent: keyboard
		key.states.add
			highlight:
				backgroundColor: "rgba(134,255,242,1)"
			normal:
				backgroundColor: "rgba(20,155,131,1)"
		key.onTouchStart (event, layer) ->
			layer.states.switch "highlight", time: 0.1, curve: "easeout"
			
		unhighlight = (event, layer) ->
			layer.states.switch "normal", time: 0.3, curve: "easeout"
		key.states.switchInstant "normal"
		
		keyLabel = new TextLayer
			color: "white"
			parent: key
			autoSize: true
			fontSize: 48
			fontFamily: "Proxima Nova"
		
		if column < 3 && row < 3
			do (digit = row * 3 + column + 1) ->
				keyLabel.text = digit
				key.onTouchEnd (event, layer) ->
					appendDigit digit
					unhighlight event, layer
		else if column == 3 && row == 0
			# Backspace
			keyLabel.text = "bspace"
			key.onTouchEnd (event, layer) ->
				if answerBuffer.number > 0
					updatePendingNumber
						number: Math.trunc(answerBuffer.number / 10)
						sign: answerBuffer.sign
				else
					# If there's no number, just remove the negative.
					updatePendingNumber { number: 0, sign: 1 }
				unhighlight event, layer
		else if column == 3 && row == 1
			# Plus/minus
			keyLabel.text = "+/–"
			key.onTouchEnd (event, layer) ->
				updatePendingNumber
					number: answerBuffer.number
					sign: answerBuffer.sign * -1
				unhighlight event, layer
		else if column == 3 && row == 2
			# Submit
			keyLabel.text = "Submit"
			key.height = keyHeight * 2 - keySpacing
			key.onTouchEnd (event, layer) ->
				# TODO
				unhighlight event, layer
		else if column == 0 && row == 3
			# Extra-wide zero key
			keyLabel.text = "0"
			key.onTouchEnd (event, layer) ->
				appendDigit 0
				unhighlight event, layer
			key.width = keyWidth * 3 - keySpacing
			
		keyLabel.center()
		
