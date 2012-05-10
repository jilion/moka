fails = (code) ->
  throws -> CoffeeScript.compile code

succeeds = (code) ->
  doesNotThrow -> CoffeeScript.compile code

test "PROTOCOL", ->
  succeeds "aProtocol = protocol"

test "PROTOCOL Block", ->
  succeeds "aProtocol = protocol\n  test: ->"

test "PROTOCOL SimpleAssignable", ->
  succeeds "protocol aProtocol"

test "PROTOCOL SimpleAssignable Block", ->
  succeeds "protocol aProtocol\n  test: ->"
  
test "PROTOCOL SimpleAssignable EXTENDS SimpleAssignable", ->
  succeeds "protocol anotherProtocol\nprotocol aProtocol extends anotherProtocol"

test "PROTOCOL SimpleAssignable EXTENDS SimpleAssignabl Block", ->
  succeeds "protocol anotherProtocol\nprotocol aProtocol extends anotherProtocol\n  test: ->"



# test 'CLASS CONFORMS ProtocolList', ->
#   protocol aProtocol
#   aClass = class conforms aProtocol
#   ok aClass
    
  # ok aClass
  
# test 'CLASS CONFORMS ProtocolList Block', ->
#   protocol aProtocol
#   class aClass conforms aProtocol
#   ok aClass
#   
#   protocol aProtocol
#   protocol anotherProtocol
#   class aClass conforms aProtocol, anotherProtocol
#   ok aClass
#   
#   
# test 'CLASS EXTENDS SimpleAssignable CONFORMS ProtocolList', ->
#   protocol aProtocol
#   class AnotherClass
#   aClass = class extends AnotherClass conforms aProtocol
#   ok aClass
  
# test 'CLASS EXTENDS SimpleAssignable CONFORMS ProtocolList Block',                  ->
# test 'CLASS SimpleAssignable CONFORMS ProtocolList',                     ->
# test 'CLASS SimpleAssignable CONFORMS ProtocolList Block',                    ->
# test 'CLASS SimpleAssignable EXTENDS SimpleAssignable CONFORMS ProtocolList',   ->   
# test 'CLASS SimpleAssignable EXTENDS SimpleAssignable CONFORMS ProtocolList Block', -> 
