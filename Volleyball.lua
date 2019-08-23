gameActive = true
serving = true

-- Concatting these strings here helps avoid memory wastage
netID = "space.sine.volleyball"
netIDPlayerAX = netID .. ".a.posX"
netIDPlayerAY = netID .. ".a.posY"
netIDPlayerBX = netID .. ".b.posX"
netIDPlayerBY = netID .. ".b.posY"
netIDballTarget = netID .. ".event"
netIDScore = netID .. ".score"

playerAX = 0
playerAY = 0
playerBX = 0
playerBY = 0

playerRangeXMin = -2
playerRangeXMax = 2
playerRangeYMin = 1.0
playerRangeYMax = 4.5

playerAScore = 0
playerBScore = 0

PaddleWidth = 1.0 or PaddleWidth

-- Doing these 'or Space.Host.ExecutingObject's gives us autocomplete on them.
PaddleA = PaddleA or Space.Host.ExecutingObject
PaddleB = PaddleB or Space.Host.ExecutingObject
Ball = Ball or Space.Host.ExecutingObject
BallMarker = BallMarker or Space.Host.ExecutingObject

ScoreAnimator = ScoreAnimator or Space.Host.ExecutingObject
PlayerAScoreText = PlayerAScoreText or Space.Host.ExecutingObject
PlayerBScoreText = PlayerBScoreText or Space.Host.ExecutingObject
DebugText = DebugText or Space.Host.ExecutingObject
ServingNotice = ServingNotice or Space.Host.ExecutingObject

ballHeight = 4
ballTarget = Vector.New(0,0,0)

ballSpeed = 3
ballSpeedMin = 3
ballSpeedMax = 7
ballSpeedIncrement = 0.5
ballStartDistance = 0

paddleSpeed = 5 -- Player movement speed is here

currentPlayer = -1
lastPlayer = -1
relays = 0

state = 0

function readPaddleRoutine() 
    while true do 
        -- Fetch values from network --- but only if we're not using the local ones
        -- otherwise we stutter (oops)
        if(currentPlayer ~= 0) then 
            playerAX = tonumber(Space.Network.GetShardProperty(netIDPlayerAX))
            playerAY = tonumber(Space.Network.GetShardProperty(netIDPlayerAY))
        end
        if(currentPlayer ~= 1) then 
            playerBX = tonumber(Space.Network.GetShardProperty(netIDPlayerBX))
            playerBY = tonumber(Space.Network.GetShardProperty(netIDPlayerBY))
        end

        if playerAX == nil then 
            playerAX = 0
        end

        if playerAY == nil then 
            playerAY = 0
        end

        if playerBX == nil then 
            playerBX = 0
        end

        if playerBY == nil then 
            playerBY = 0
        end

        state = 1


        -- Apply inputs
        if (currentPlayer >= 0) then
            state = 3

            movement = Space.Input.MovementAxis

            -- Technically diagonal movement is faster, todo; fix me later?
            if(currentPlayer == 0) then

                playerAX = playerAX + ((movement.X * Space.DeltaTime) * paddleSpeed)
                playerAY = playerAY + ((movement.Y * Space.DeltaTime) * paddleSpeed * -1)

                -- Clamp values to inside box
                playerAX = Space.Math.Clamp(playerAX, playerRangeXMin, playerRangeXMax)
                playerAY = Space.Math.Clamp(playerAY, playerRangeYMin, playerRangeYMax)
            elseif (currentPlayer==1) then
                playerBX = playerBX + ((movement.X * Space.DeltaTime) * paddleSpeed)
                playerBY = playerBY + ((movement.Y * Space.DeltaTime) * paddleSpeed * -1)

                -- Clamp values to inside box
                playerBX = Space.Math.Clamp(playerBX, playerRangeXMin, playerRangeXMax)
                playerBY = Space.Math.Clamp(playerBY, playerRangeYMin, playerRangeYMax)
            end
        end

        if (gameActive and not serving) then
            state = 2

            -- Ball Dynamics
            ballPos = Ball.LocalPosition
            ballPos = ballPos.MoveTowards(ballTarget, ballSpeed * Space.DeltaTime)
            ballPos.y = 0
            ballTarget.y = 0
            distanceFraction = Space.Math.Clamp(ballPos.Distance(ballTarget) / ballStartDistance, 0, 1)

            -- parabolic arc, worked out on wolfram alpha -- clamp eliminates NaN
            ballPos.y = Space.Math.Clamp((1.0 - Space.Math.Pow(((distanceFraction*2)-1)/2, 2)*4) * ballHeight,0,ballHeight)
            
            Ball.LocalPosition = ballPos

            ballPos.y = 0
            BallMarker.LocalPosition = ballPos

            -- Scoring
            if (ballPos.Distance(ballTarget) < 0.01) then -- we use 0.05 instead of == 0.0 as floats can be untrustworthy
                if (PaddleA.LocalPosition.Distance(Ball.LocalPosition) < PaddleWidth and currentPlayer == 0) then
                    pingBallA()
                elseif (PaddleB.LocalPosition.Distance(Ball.LocalPosition) < PaddleWidth and currentPlayer == 1) then
                    pingBallB()
                else 
                    -- serving player gets a point
                    serving = true

                    if(lastPlayer ~= currentPlayer) then
                        if(currentPlayer == 0) then
                            playerAScore = playerAScore + 1
                        end

                        if(currentPlayer == 1) then
                            playerBScore = playerBScore + 1
                        end

                        Space.Network.SendNetworkMessage(netIDScore,{ playerAScore, playerBScore})
                        PlayerAScoreText.UIText.Text = playerAScore
                        PlayerBScoreText.UIText.Text = playerBScore
                    end
                end

            end
        elseif (serving == true) then
            state = 5

            if (currentPlayer >= 0) then
                state = 6

                if(lastPlayer ~= currentPlayer) then
                    state = 7
                    
                    if (Space.Input.GetKeyUp("space")) then
                        if(currentPlayer == 0) then
                            state = 8
                            relays = -1
                            pingBallA()
                            serving = false
                        end
                        if(currentPlayer == 1) then
                            state = 9
                            relays = -1
                            pingBallB()
                            serving = false
                        end
                    end
                end
            end
        end

        -- Sets the paddles into their desired positions
        if (playerAY > 0) then
            local t = PaddleA.LocalPosition
            t.X = playerAX
            t.Y = 0
            t.Z = playerAY * -1
            PaddleA.LocalPosition = t
        end
        if (playerBY > 0) then
            local t = PaddleB.LocalPosition
            t.X = playerBX * -1 -- keyboard is reversed on other side
            t.Y = 0
            t.Z = playerBY
            PaddleB.LocalPosition = t
        end

        if(ServingNotice.Active ~= serving) then
            ServingNotice.Active = serving
        end

        DebugText.UIText.Text = state

        coroutine.yield(0)
    end
end

-- "Ping" ball back to other side
function pingBallA()
    lastPlayer = currentPlayer
    ballTarget = PaddleB.LocalPosition
    ballTarget.X = Space.Math.RandomRange(playerRangeXMin, playerRangeXMax)
    ballTarget.Y = 0
    ballTarget.Z = Space.Math.RandomRange(playerRangeYMin, playerRangeYMax)
    distTmp = Ball.LocalPosition
    distTmp.Y = 0
    ballStartDistance = ballTarget.Distance(distTmp)
    relays = relays + 1
    ballSpeed = Space.Math.Clamp(ballSpeed + relays * ballSpeedIncrement, ballSpeedMin, ballSpeedMax)

    Space.Network.SendNetworkMessage(netIDballTarget, { ballTarget.X, ballTarget.Z, ballStartDistance, currentPlayer, relays, ballSpeed })
    ScoreAnimator.Animator.SetFloat("Relays", relays / 15.0)
end

function pingBallB() 
    lastPlayer = currentPlayer
    ballTarget = PaddleA.LocalPosition
    ballTarget.X = Space.Math.RandomRange(playerRangeXMin, playerRangeXMax)
    ballTarget.Y = 0
    ballTarget.Z = Space.Math.RandomRange(-playerRangeYMin, -playerRangeYMax) -- flipped as B is in negatives
    distTmp = Ball.LocalPosition
    distTmp.Y = 0
    ballStartDistance = ballTarget.Distance(distTmp)
    relays = relays + 1
    ballSpeed = Space.Math.Clamp(ballSpeed + relays * ballSpeedIncrement, ballSpeedMin, ballSpeedMax)

    Space.Network.SendNetworkMessage(netIDballTarget, { ballTarget.X, ballTarget.Z, ballStartDistance, currentPlayer, relays, ballSpeed })
    ScoreAnimator.Animator.SetFloat("Relays", relays / 15.0)
end

-- Exposed in Unity Inspector
function OnPlayerSeatA() 
    currentPlayer = 0
    lastPlayer = -2
    Space.Network.SendNetworkMessage(netIDScore,{ 0, 0})
end

function OnPlayerSeatB() 
    currentPlayer = 1
    lastPlayer = -2
    Space.Network.SendNetworkMessage(netIDScore,{ 0, 0})
end

function OnPlayerUnsit()
    currentPlayer = -1
    lastPlayer = -2
    Space.Network.SendNetworkMessage(netIDScore,{ 0, 0})
end

-- For keeping our network stuff in sync on a even timer
function networkSyncLoop() 
    while true do 
        if(gameActive) then
            if(currentPlayer == 0) then
                -- Set network values
                Space.Network.SetShardProperty(netIDPlayerAX, playerAX)
                Space.Network.SetShardProperty(netIDPlayerAY, playerAY)
            end
            if(currentPlayer == 1) then
                -- Set network values
                Space.Network.SetShardProperty(netIDPlayerBX, playerBX)
                Space.Network.SetShardProperty(netIDPlayerBY, playerBY)
            end
        end

        coroutine.yield(1 / 4.0) -- sync no more than every 250ms
                                 -- this stops the angry watchdog
                                 -- and leaves some room for messages
                                 -- update: div by two since two calls
    end
end

function onRecieveTarget(msg) 
    if (msg.Key ~= netIDballTarget) then 
        return
    end

    dataTable = msg.Message
    -- dataTable = { ballTarget.X, ballTarget.Y, ballStartDistance, currentPlayer, relays, ballSpeed }
    ballTarget = Vector.New(dataTable[1], 0, dataTable[2])
    ballStartDistance = dataTable[3]
    lastPlayer = dataTable[4]
    relays = dataTable[5]
    ballSpeed = dataTable[6]
    serving = false
    ScoreAnimator.Animator.SetFloat("Relays", relays / 15.0)
end

function onRecieveScores(msg) 
    if (msg.Key ~= netIDScore) then 
        return
    end

    dataTable = msg.Message
    -- dataTable = { playerAScore, playerBScore }
    
    serving = true -- whenever this happens the game has reset too, serving is a neutral state

    playerAScore = dataTable[1]
    playerBScore = dataTable[2]
    PlayerAScoreText.UIText.Text = playerAScore
    PlayerBScoreText.UIText.Text = playerBScore
end

Space.Network.SubscribeToNetwork(netIDballTarget, onRecieveTarget)
Space.Network.SubscribeToNetwork(netIDScore, onRecieveScores)
Space.Host.StartCoroutine(readPaddleRoutine)
Space.Host.StartCoroutine(networkSyncLoop)