[ESC, UP, DOWN, LEFT, RIGHT, A, B, R] = [27, 38, 40, 37, 39, 65, 66, 82]
initialSnake = [[19, 10], [20, 10], [21, 10], [22, 10], [23, 10], [24, 10], [25, 10]]
sadFace = [[18,  8], [21,  8], [17, 12], [18, 11], [19, 11], [20, 11], [21, 11], [22, 12]]

lg = (prefix='lg') -> console.log.bind console, prefix

moveSnake = (snake, direction) ->
    [init..., end] = snake
    [neckX, neckY] = init[0]

    head = switch direction
        when UP
            [neckX, neckY-1]
        when DOWN
            [neckX, neckY+1]
        when LEFT
            [neckX-1, neckY]
        when RIGHT
            [neckX+1, neckY]

    return [head, init...]

keyboardStream = Rx.Observable.fromEvent document.body, 'keyup'

showStream = keyboardStream
    .map ({keyCode}) -> keyCode
    .bufferWithCount(10, 1)
    .filter((keyCodes) -> _.isEqual keyCodes, [UP, UP, DOWN, DOWN, LEFT, RIGHT, LEFT, RIGHT, B, A] )

hideStream = keyboardStream.filter ({keyCode}) -> keyCode is ESC

# debug
showStream = keyboardStream.filter ({keyCode}) -> keyCode is B

showStream = showStream.flatMap (v) -> Rx.Observable.of(v)
    .concat(keyboardStream.filter ({keyCode}) -> keyCode is R)
    .takeUntil hideStream

displayStream = Rx.Observable.merge(
        showStream.map(true)
        hideStream.map(false)
    )
    .distinctUntilChanged()

canvasStream = showStream
    .take(1)
    .doAction ->
        canvas = document.createElement 'canvas'
        canvas.width = 400
        canvas.height = 200
        document.getElementById('wrapper').appendChild(canvas)
    .map -> document.querySelector('#wrapper canvas')
    .share()

displayStream
    .combineLatest canvasStream, _.identity
    .subscribe (display) ->
        document.querySelector('#wrapper img').hidden = display
        document.querySelector('#wrapper canvas').hidden = not display

fieldStream = new Rx.Subject()
fieldStream
    .combineLatest canvasStream, (field, canvas) -> {field, canvas}
    .subscribe ({field, canvas}) ->
        ctx = canvas.getContext "2d"
        ctx.clearRect(0, 0, canvas.width, canvas.height - 10)

        for [x, y] in field
            ctx.fillStyle = "#000000"
            ctx.fillRect(10*x, 10*y, 10, 10)

statusStream = new Rx.Subject()
statusStream
    .combineLatest canvasStream, (status, canvas) -> {status, canvas}
    .subscribe ({status, canvas}) ->
        ctx = canvas.getContext "2d"
        ctx.fillStyle = "#00A500"
        ctx.fillRect(0, canvas.height - 10, canvas.width, 10)

        ctx.fillStyle = "#FFFFFF"
        ctx.fillText(status, 5, canvas.height - 1)

pauseStream = new Rx.Subject()

ticker = showStream
    .flatMap ->
        Rx.Observable.just(-1)
            .concat(Rx.Observable.interval(200))
            .map (index) -> index+1
            .takeUntil hideStream
            .takeUntil pauseStream

directionStream = keyboardStream
    .map ({keyCode}) -> keyCode
    .filter (keyCode) -> keyCode in [UP, DOWN, LEFT, RIGHT]
    .scan DOWN, (prev, next) ->
        switch next
            when UP, DOWN
                if prev in [LEFT, RIGHT] then next else prev
            when LEFT, RIGHT
                if prev in [UP, DOWN] then next else prev
    .merge showStream.map(DOWN)

snakeStream = ticker
    .withLatestFrom(
        directionStream
        (index, direction) -> {index, direction}
    )
    .scan initialSnake, (prevSnake, {index, direction}) ->
        if index then moveSnake(prevSnake, direction) else initialSnake
    .map (snake) ->
        [headX, headY] = snake[0]
        if (
            0 <= headX < 40 and
            0 <= headY < 19 and
            not _.findWhere(_.tail(snake), snake[0])
        )
            return snake
        else
            pauseStream.onNext(null)
            return sadFace
    .subscribe fieldStream

ticker
    .subscribe (index) ->
        statusStream.onNext index
