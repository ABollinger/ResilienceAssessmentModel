extensions[matpowerconnect] 

globals [
  matpower-total-bus-list
  matpower-total-generator-list
  matpower-total-link-list
  matpower-total-gencost-list
  matpower-input-list
  matpower-output-list
  total-generator-output
  links-killed-this-tick
  links-overloaded-this-tick
  links-failed-due-to-overload
  demand-response?
  event-magnitude
  fraction-demand-served
  repair-counter
]

breed [grid-operators grid-operator]
breed [consumers consumer]
breed [producers producer]

breed [buses bus]
breed [generators generator]
breed [loads load]

undirected-link-breed [bus-links bus-link]
undirected-link-breed [component-links component-link]

grid-operators-own [
  grid-operator-buses
  grid-operator-bus-links
]

consumers-own [
  consumer-satisfaction
  consumer-demand
  consumer-loads
  consumer-distributed-generation-capacity
]

producers-own [
  producer-generators
]

buses-own [
  
  bus-list ;the matpower list for each bus  
  bus-power-injected
  
  ;matpower variables                                          
  bus-number ;matpower variable               
  bus-type-matpower ;matpower variable             
  bus-real-power-demand ;matpower variable
  bus-reactive-power-demand ;matpower variable
  bus-shunt-conductance ;matpower variable
  bus-shunt-susceptance ;matpower variable
  bus-area-number ;matpower variable
  bus-voltage-magnitude ;matpower variable
  bus-voltage-angle ;matpower variable
  bus-base-voltage ;matpower variable
  bus-loss-zone ;matpower variable
  bus-maximum-voltage-magnitude ;matpower variable
  bus-minimum-voltage-magnitude ;matpower variable
]

generators-own [
  
  generator-bus
  generator-number
  generator-list ;the matpower list for each generator
  generator-cost-list
  
  ;matpower variables    
  generator-real-power-output             
  generator-reactive-power-output 
  generator-maximum-reactive-power-output
  generator-minimum-reactive-power-output 
  generator-voltage-magnitude-setpoint 
  generator-mbase
  generator-matpower-status  
  generator-maximum-real-power-output  
  generator-minimum-real-power-output 
  generator-lower-real-power-output  
  generator-upper-real-power-output  
  generator-mimimum-reactive-power-output-at-pc1   
  generator-maximum-reactive-power-output-at-pc1   
  generator-mimimum-reactive-power-output-at-pc2  
  generator-maximum-reactive-power-output-at-pc2 
  generator-ramp-rate-load
  generator-ramp-rate-10-min  
  generator-ramp-rate-30-min 
  generator-ramp-rate-reactive    
  generator-area-participation-factor
  
  gencost-model
  gencost-startup-cost
  gencost-shutdown-cost
  gencost-number-coefficients
  gencost-parameters
]

loads-own [
  load-default-power-demand
  load-power-demand
  load-power-received
  load-bus
]

bus-links-own [
  
  link-number
  link-load
  link-capacity
  link-status-counter
  link-list ;the matpower list for each link
  matpower-link-results-list ;the matpower output for the link
  
  ;matpower variables
  link-from-bus-number
  link-to-bus-number
  link-resistance
  link-reactance
  link-total-line-charging-susceptance
  link-rate-a
  link-rate-b
  link-rate-c
  link-ratio
  link-angle
  link-status
  link-minimum-angle-difference
  link-maximum-angle-difference
  
  link-power-injected-from-end
  link-power-injected-to-end
]


to setup
  
  clear-all
  reset-ticks
  
  set links-killed-this-tick 0
  set links-overloaded-this-tick 0
  set links-failed-due-to-overload 0
  set demand-response? false
  
  ifelse (case-to-load = "random network") [setup-random-network] [load-case-data]
  setup-actors
  set-link-capacities
  if (increase-link-capacity?) [ask bus-links [set link-capacity link-capacity * 2]]
  
  setup-power-flows-plot
  adjust-network-layout
  update-visualization
  
end


to go
  
  set links-killed-this-tick 0
  set links-overloaded-this-tick 0
  
  ask grid-operators [repair-links]
  if (probability-of-extreme-event > random-float 100) [create-extreme-event-and-kill-links]
  if (kill-random-links? and ticks > 1 and ticks mod 10 = 0 and count bus-links with [link-status = 1] > 0) [kill-random-link]
  if (allow-demand-response?) [ask grid-operators [set demand-response? true]]
  
  calculate-power-flows-and-overloads
  update-consumer-satisfaction
  calculate-fraction-demand-served
  
  if (add-backup-generators?) [switch-to-backup-generation]
  if (consumers-invest-in-distributed-generation?) [ask consumers [invest-in-distributed-generation]]
    
  update-visualization
  update-the-plots
  
  tick
  
end


;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup-random-network
  
  let i 1
  let previous-bus nobody
  create-buses number-of-substations [
    set bus-number i
    set bus-real-power-demand 0
    set bus-reactive-power-demand 0
    set bus-shunt-conductance 0
    set bus-shunt-susceptance 0
    set bus-area-number 1
    set bus-voltage-magnitude 1
    set bus-voltage-angle 0
    set bus-base-voltage 380
    set bus-loss-zone 1
    set bus-maximum-voltage-magnitude 1.1
    set bus-minimum-voltage-magnitude 0.9
    
    if (previous-bus != nobody) [
      create-bus-link-with previous-bus [
        set link-capacity 0
        set link-status-counter 0
        set link-from-bus-number [bus-number] of end1
        set link-to-bus-number [bus-number] of end2
        set link-resistance 0.00000000001
        set link-reactance 0.00000000001
        set link-total-line-charging-susceptance 0
        set link-rate-a 250
        set link-rate-b 250
        set link-rate-c 250
        set link-ratio 0
        set link-angle 0
        set link-status 1
        set link-minimum-angle-difference -360
        set link-maximum-angle-difference 360
      ]
    ]
    
    set i i + 1
    set previous-bus self
  ]
  
  repeat number-of-redundant-lines [
    ask one-of buses [
      create-bus-link-with one-of other buses [
        set link-capacity 0
        set link-status-counter 0
        set link-from-bus-number [bus-number] of end1
        set link-to-bus-number [bus-number] of end2
        set link-resistance 0.00000000001
        set link-reactance 0.00000000001
        set link-total-line-charging-susceptance 0
        set link-rate-a 250
        set link-rate-b 250
        set link-rate-c 250
        set link-ratio 0
        set link-angle 0
        set link-status 1
        set link-minimum-angle-difference -360
        set link-maximum-angle-difference 360
      ]
    ]
  ]  
  
  create-loads number-of-loads [
    create-component-link-with one-of buses
    set load-power-demand 0
    set load-bus one-of component-link-neighbors
  ]
  
  let j 1
  create-generators number-of-generators [
    create-component-link-with one-of buses
    set generator-number j
    set generator-bus one-of component-link-neighbors
    set generator-real-power-output 0           
    set generator-reactive-power-output 0
    set generator-maximum-reactive-power-output 0
    set generator-minimum-reactive-power-output 0
    set generator-voltage-magnitude-setpoint 1
    set generator-mbase 100
    set generator-matpower-status 1
    set generator-maximum-real-power-output 0
    set generator-minimum-real-power-output 0
    set generator-lower-real-power-output 0
    set generator-upper-real-power-output 0
    set generator-mimimum-reactive-power-output-at-pc1 0
    set generator-maximum-reactive-power-output-at-pc1 0
    set generator-mimimum-reactive-power-output-at-pc2 0
    set generator-maximum-reactive-power-output-at-pc2 0
    set generator-ramp-rate-load 0
    set generator-ramp-rate-10-min 0
    set generator-ramp-rate-30-min 0
    set generator-ramp-rate-reactive 0
    set generator-area-participation-factor 0
    
    set gencost-model 2
    set gencost-startup-cost 3000
    set gencost-shutdown-cost 0 
    set gencost-number-coefficients 3
    set gencost-parameters (list 0.1225 1 335)
    
    set j j + 1
  ]
  
end


to load-case-data
  if (case-to-load = "IEEE case 9") [file-open "casedata/case9_busdata"]
  if (case-to-load = "IEEE case 14") [file-open "casedata/case14_busdata"]
  if (case-to-load = "IEEE case 30") [file-open "casedata/case30_busdata"]
  if (case-to-load = "IEEE case 118") [file-open "casedata/case118_busdata"]
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    create-buses 1 [
      set bus-number item 0 current-line
      set bus-real-power-demand item 2 current-line
      set bus-reactive-power-demand item 3 current-line
      set bus-shunt-conductance item 4 current-line
      set bus-shunt-susceptance item 5 current-line
      set bus-area-number item 6 current-line
      set bus-voltage-magnitude item 7 current-line
      set bus-voltage-angle item 8 current-line
      set bus-base-voltage item 9 current-line
      set bus-loss-zone item 10 current-line
      set bus-maximum-voltage-magnitude item 11 current-line
      set bus-minimum-voltage-magnitude item 12 current-line
    ]
  ]
  file-close
  
  ask buses with [bus-real-power-demand > 0] [
    hatch-loads 1 [
      set load-default-power-demand [bus-real-power-demand] of myself
      set load-bus myself
      create-component-link-with myself
    ]
  ]
  
  if (case-to-load = "IEEE case 9") [file-open "casedata/case9_generatordata"]
  if (case-to-load = "IEEE case 14") [file-open "casedata/case14_generatordata"]
  if (case-to-load = "IEEE case 30") [file-open "casedata/case30_generatordata"]
  if (case-to-load = "IEEE case 118") [file-open "casedata/case118_generatordata"]
  let i 0
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    set i i + 1
    create-generators 1 [
      set generator-number i
      set generator-bus one-of buses with [bus-number = item 0 current-line]
      set generator-real-power-output item 1 current-line             
      set generator-reactive-power-output item 2 current-line 
      set generator-maximum-reactive-power-output item 3 current-line 
      set generator-minimum-reactive-power-output item 4 current-line 
      set generator-voltage-magnitude-setpoint item 5 current-line 
      set generator-mbase item 6 current-line 
      set generator-matpower-status item 7 current-line 
      set generator-maximum-real-power-output item 8 current-line 
      set generator-minimum-real-power-output item 9 current-line 
      set generator-lower-real-power-output item 10 current-line 
      set generator-upper-real-power-output item 11 current-line 
      set generator-mimimum-reactive-power-output-at-pc1 item 12 current-line 
      set generator-maximum-reactive-power-output-at-pc1 item 13 current-line 
      set generator-mimimum-reactive-power-output-at-pc2 item 14 current-line 
      set generator-maximum-reactive-power-output-at-pc2 item 15 current-line 
      set generator-ramp-rate-load item 16 current-line 
      set generator-ramp-rate-10-min item 17 current-line 
      set generator-ramp-rate-30-min item 18 current-line 
      set generator-ramp-rate-reactive item 19 current-line 
      set generator-area-participation-factor item 20 current-line 
      
      create-component-link-with generator-bus
    ]
  ]
  file-close
  
  if (case-to-load = "IEEE case 9") [file-open "casedata/case9_linedata"]
  if (case-to-load = "IEEE case 14") [file-open "casedata/case14_linedata"]
  if (case-to-load = "IEEE case 30") [file-open "casedata/case30_linedata"]
  if (case-to-load = "IEEE case 118") [file-open "casedata/case118_linedata"]
  set i 0
  while [not file-at-end?] [
    set i i + 1
    let current-line read-from-string (word "[" file-read-line "]")
    let bus1 one-of buses with [bus-number = item 0 current-line]
    let bus2 one-of buses with [bus-number = item 1 current-line]
    ask bus1 [
      create-bus-link-with bus2 [
        set link-number i
        set link-capacity 0
        set link-status-counter 0
        set link-from-bus-number item 0 current-line
        set link-to-bus-number item 1 current-line
        set link-resistance item 2 current-line
        set link-reactance item 3 current-line
        set link-total-line-charging-susceptance item 4 current-line
        set link-rate-a item 5 current-line
        set link-rate-b item 6 current-line
        set link-rate-c item 7 current-line
        set link-ratio item 8 current-line
        set link-angle item 9 current-line
        set link-status item 10 current-line
        set link-minimum-angle-difference item 11 current-line
        set link-maximum-angle-difference item 12 current-line
      ]
    ]
  ]
  file-close
  
  if (case-to-load = "IEEE case 9") [file-open "casedata/case9_gencostdata"]
  if (case-to-load = "IEEE case 14") [file-open "casedata/case14_gencostdata"]
  if (case-to-load = "IEEE case 30") [file-open "casedata/case30_gencostdata"]
  if (case-to-load = "IEEE case 118") [file-open "casedata/case118_gencostdata"]
  set i 0
  while [not file-at-end?] [
    set i i + 1
    let current-line read-from-string (word "[" file-read-line "]")
    ask one-of generators with [generator-number = i] [
      set gencost-model item 0 current-line 
      set gencost-startup-cost item 1 current-line 
      set gencost-shutdown-cost item 2 current-line 
      set gencost-number-coefficients item 3 current-line
      set gencost-parameters []
      
      let j 1
      while [j <= gencost-number-coefficients] [
        set gencost-parameters lput (item (j + 3) current-line) gencost-parameters
        set j j + 1
      ]
    ]
  ]
  file-close
  
end


to setup-actors
  
  create-grid-operators 1 [
    set grid-operator-buses turtle-set buses
    set grid-operator-bus-links link-set bus-links
  ]
  
  ask loads [
    hatch-consumers 1 [
      set consumer-loads turtle-set myself
      set consumer-distributed-generation-capacity 0
    ]
  ]
  
  ask generators [
    hatch-producers 1 [
      set producer-generators turtle-set myself
    ]
  ]
  
end


to set-link-capacities
  
  set-consumer-demand
  set-generator-capacities
  set-generator-outputs
  set-power-demand-of-buses
    
  create-matpower-lists
  create-final-matpower-list
  run-matpower 
  
  ask bus-links [
    set link-capacity link-load * 1.1
  ]
  
end


to setup-power-flows-plot

  ;create a pen for each link in the power flow plot
  set-current-plot "power line flows"
  let pen-name ""
  ask bus-links [
    set pen-name word [bus-number] of end1 [bus-number] of end2
    create-temporary-plot-pen pen-name
    set-plot-pen-color 0
  ]
  
end

to set-consumer-demand
  
  ifelse (use-default-demand-and-generation-values?) [
    ask consumers [set consumer-demand sum [load-default-power-demand] of consumer-loads]
  ]
  [
    ask consumers [set consumer-demand random-normal mean-power-demand-of-consumers stddev-power-demand-of-consumers]
  ]
  
  if (demand-response?) [
    ask consumers [set consumer-demand consumer-demand * 0.5]
  ]
  
end


to set-generator-capacities
  
  if (use-default-demand-and-generation-values? = false) [
    ask generators [set generator-maximum-real-power-output capacity-of-generators]
  ]
  
end


to create-extreme-event-and-kill-links

  set event-magnitude random count bus-links + 1
  repeat event-magnitude [
    if (count bus-links with [link-status = 1] > 0) [kill-random-link]
  ]

end
 
 
to kill-random-link
  
  ask one-of bus-links with [link-status = 1] [
    set link-status 0
    set links-killed-this-tick links-killed-this-tick + 1
    set repair-counter link-repair-time
  ]
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; POWER FLOW / CONTINGENCY ANALYSIS PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to calculate-power-flows-and-overloads
  
  set-consumer-demand
  set-generator-capacities
  set-generator-outputs
  set-power-demand-of-buses
  
  create-matpower-lists
  create-final-matpower-list
  run-matpower 
  kill-overloaded-links
  
  if (links-failed-due-to-overload > 0) [calculate-power-flows-and-overloads]
  
end


;this is now performed by the extension and can be deleted
to set-generator-outputs
  
  let demand-sum sum [consumer-demand] of consumers
  let total-generation-capacity sum [generator-maximum-real-power-output] of generators
  let demand-supply-ratio demand-sum / total-generation-capacity
  
  ifelse (total-generation-capacity >= demand-sum) [
    ask generators [set generator-real-power-output generator-maximum-real-power-output * demand-supply-ratio]
  ]
  [
    ask generators [set generator-real-power-output generator-maximum-real-power-output]
    ask consumers [set consumer-demand consumer-demand / demand-supply-ratio]
  ] 
  
end


;this is now performed by the extension and can be deleted
to set-matpower-bus-types
  
  ;initially, set all the buses to be PQ (load) buses
  ask buses [
    set bus-type-matpower 1
  ]
  
  ;set the buses connected to generators to be PV (generator) buses
  ask generators with [generator-bus != nobody] [
    ask generator-bus [set bus-type-matpower 2] ;change the connected buses to PV buses
  ]

  ;set one of the generator buses to be a reference (slack) bus
  ask one-of generators with [generator-bus != nobody] [
    ask generator-bus [set bus-type-matpower 3] ;make it a generator bus
  ]

end


to set-power-demand-of-buses
  
  ;set the real power demand of the buses equal to the sum of the power demand of their connected consumers
  ask buses [
    set bus-real-power-demand 0
    set bus-reactive-power-demand 0
  ]
  
  ask consumers [
    ask consumer-loads [
      set load-power-demand [consumer-demand - consumer-distributed-generation-capacity] of myself
      ask load-bus [
        set bus-real-power-demand bus-real-power-demand + [load-power-demand] of myself
        set bus-reactive-power-demand 0
      ]
    ]
  ]

end


;create the bus, generator and link lists for each individual bus, generator and link
to create-matpower-lists
  
  ask buses [
    set bus-list 
      (list 
        bus-number 
        bus-type-matpower 
        bus-real-power-demand 
        bus-reactive-power-demand 
        bus-shunt-conductance 
        bus-shunt-susceptance 
        bus-area-number 
        bus-voltage-magnitude 
        bus-voltage-angle 
        bus-base-voltage 
        bus-loss-zone 
        bus-maximum-voltage-magnitude 
        bus-minimum-voltage-magnitude)
  ]
  
  ask generators [
    set generator-list 
        (list 
          [bus-number] of generator-bus
          generator-real-power-output 
          generator-reactive-power-output 
          generator-maximum-reactive-power-output 
          generator-minimum-reactive-power-output 
          generator-voltage-magnitude-setpoint 
          generator-mbase 
          generator-matpower-status 
          generator-maximum-real-power-output 
          generator-minimum-real-power-output 
          generator-lower-real-power-output 
          generator-upper-real-power-output 
          generator-mimimum-reactive-power-output-at-pc1 
          generator-maximum-reactive-power-output-at-pc1 
          generator-mimimum-reactive-power-output-at-pc2 
          generator-maximum-reactive-power-output-at-pc2 
          generator-ramp-rate-load 
          generator-ramp-rate-10-min 
          generator-ramp-rate-30-min 
          generator-ramp-rate-reactive 
          generator-area-participation-factor)
        
     set generator-cost-list
        (list
          gencost-model
          gencost-startup-cost
          gencost-shutdown-cost
          gencost-number-coefficients)
       
     foreach gencost-parameters [
       set generator-cost-list lput ? generator-cost-list
     ]    
  ]
  
  ask bus-links [
    set link-list 
      (list 
        link-from-bus-number 
        link-to-bus-number 
        link-resistance 
        link-reactance 
        link-total-line-charging-susceptance 
        link-rate-a 
        link-rate-b 
        link-rate-c 
        link-ratio 
        link-angle 
        link-status 
        link-minimum-angle-difference 
        link-maximum-angle-difference)
  ]

end


to create-final-matpower-list
  
  ;create the bus list for matpower
  set matpower-total-bus-list [] ;create an empty total bus list
  ask buses [set matpower-total-bus-list lput bus-list matpower-total-bus-list] ;add each bus list to the total bus list
  set matpower-total-bus-list sort-by [first ?1 < first ?2] matpower-total-bus-list ;sort the total bus list by bus number. this is necessary; otherwise matpower sometimes fails
  
  ;create the gen list and gencost list for matpower
  set matpower-total-generator-list [] ;create an empty total generator list
  set matpower-total-gencost-list []
  ;ask generators with [count [my-bus-links with [link-status = 1]] of generator-bus > 0] [
  ask generators [
    set matpower-total-generator-list lput generator-list matpower-total-generator-list ;add each generator list to the total generator list
    set matpower-total-gencost-list lput generator-cost-list matpower-total-gencost-list
  ]
  ;set total-generator-list sort-by [first ?1 < first ?2] total-generator-list ;sort the total generator list by the generator-number
  ;foreach total-generator-list [set ? remove-item 0 ?] ;delete the generator numbers from the total-generator-list. matpower doesn't need this - it's only for our own accounting
  
  ;create the link list for matpower
  set matpower-total-link-list [] ;create an empty total link list
  ask bus-links [set matpower-total-link-list lput link-list matpower-total-link-list] ;for each link that is functional, add the link list to the total link list
  ;set matpower-total-link-list sort-by [item 1 ?1 < item 1 ?2] matpower-total-link-list ;sort the total link list by the bus number of the from end
  ;set matpower-total-link-list sort-by [first ?1 < first ?2] matpower-total-link-list ;sort the total link list by the bus number of the to end
  
  ;set the extra variables for matpower
  let basemva 100
  let area [1 1]
  
  ;assemble the final list to be inputted to matpower
  ;set matpower-input-list (list basemva matpower-total-bus-list matpower-total-generator-list matpower-total-link-list matpower-total-gencost-list area analysis) 
  set matpower-input-list (list basemva matpower-total-bus-list matpower-total-generator-list matpower-total-link-list area) 
  if (print-power-flow-data?) [print matpower-input-list]

end


to run-matpower 
  
  ;reset the component values
  ask bus-links [set link-load 0]
  ask buses [set bus-power-injected 0]
  set total-generator-output 0
  
  ;check to make sure we're passing a feasible network to the matpowerconnect extension
  ifelse (length item 1 matpower-input-list > 0 and length item 2 matpower-input-list > 0 and length item 3 matpower-input-list > 0 and length item 4 matpower-input-list > 0) [    
    ;pass the input list to matpower
    set matpower-output-list matpowerconnect:octavetest matpower-input-list
    if (print-power-flow-data?) [print matpower-output-list]
    
    ;parse the output list
    let matpower-link-output-data item 0 matpower-output-list
    let matpower-generator-output-data item 1 matpower-output-list
    
    ask buses [set bus-power-injected 0] ;reset the bus-power-injected value
    
                                         ;set the link loads and bus injections based on the matpower results
    ask bus-links with [link-status = 1] [
      
      foreach matpower-link-output-data [
        if (item 0 ? = link-from-bus-number AND item 1 ? = link-to-bus-number) [set matpower-link-results-list ?] ;if the numbers of the from bus and the to bus match, extract the data for this link
      ]
      
      set link-power-injected-from-end item 2 matpower-link-results-list
      set link-power-injected-to-end item 3 matpower-link-results-list
      set link-load item 4 matpower-link-results-list
      
      ask one-of buses with [bus-number = [link-from-bus-number] of myself] [
        set bus-power-injected bus-power-injected - [link-power-injected-from-end] of myself
      ]
      ask one-of buses with [bus-number = [link-to-bus-number] of myself] [
        set bus-power-injected bus-power-injected - [link-power-injected-to-end] of myself
      ]
    ]
    
    ask bus-links with [link-status = 0] [
      set link-load 0
    ]
    
    ;add the generator injections to the buses and calculate the total generator output
    set total-generator-output 0
    foreach matpower-generator-output-data [
      ask one-of buses with [bus-number = item 0 ?] [
        set bus-power-injected bus-power-injected + item 1 ?
        set total-generator-output total-generator-output + item 1 ?
      ]
    ]
  ]
  [
    print "Infeasible network.  Network not passed to the extension."
  ]

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; USING THE POWER FLOW / CONTINGENCY ANALSYSIS RESULTS ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to repair-links
  
  ifelse (repair-counter = 0) [
    ask bus-links [set link-status 1]
  ]
  [
    set repair-counter repair-counter - 1
  ]
  
;  ask bus-links with [link-status = 0 and link-status-counter = 0] [
;    set link-status 1
;  ]
;  ask bus-links with [link-status = 0 and link-status-counter > 0] [
;    set link-status-counter link-status-counter - 1
;  ]
  
end


to kill-overloaded-links
  
  set links-failed-due-to-overload 0
  
  ask bus-links with [link-status = 1] [
    if (link-load > link-capacity) [
      set link-status 0
      set links-failed-due-to-overload links-failed-due-to-overload + 1
      set links-overloaded-this-tick links-overloaded-this-tick + 1
    ]
  ]
  
end


to update-consumer-satisfaction

  ;calculate the power received by the loads
  ask loads [
    set load-power-received ([bus-power-injected] of one-of component-link-neighbors / [count component-link-neighbors with [breed = loads]] of one-of component-link-neighbors)
  ] 
  
  ;set consumer satisfaction
  ask consumers [
    set consumer-satisfaction ((sum [load-power-received] of consumer-loads) + consumer-distributed-generation-capacity) / consumer-demand
  ]
    
end


to calculate-fraction-demand-served
  
  let total-power-received 0
  let total-power-demanded 0
  
  ask consumers [
    set total-power-received total-power-received + sum [load-power-received] of consumer-loads
    set total-power-received total-power-received + consumer-distributed-generation-capacity
    set total-power-demanded total-power-demanded + consumer-demand
  ]
  
  set fraction-demand-served total-power-received / total-power-demanded
    
end


to switch-to-backup-generation
  
  ask consumers [
    if (consumer-satisfaction < 0.5 and consumer-distributed-generation-capacity = 0) [
      set consumer-distributed-generation-capacity consumer-demand * 0.75
    ]
  ]
  
  calculate-power-flows-and-overloads
  update-consumer-satisfaction
  calculate-fraction-demand-served
  
  ask consumers [set consumer-distributed-generation-capacity 0]
  
end


to invest-in-distributed-generation

  if (consumer-satisfaction < 0.9) [
    set consumer-distributed-generation-capacity consumer-demand
  ]

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; VISUALIZATION PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to adjust-network-layout
  
  repeat 5000 [ layout-spring (turtle-set buses generators loads) (link-set bus-links component-links) 0.1 0.1 1 ]

end


to update-the-plots
  
  set-current-plot "link load vs. consumer satisfaction"
  plotxy mean [link-load] of bus-links mean [consumer-satisfaction] of consumers
  
end


to update-visualization
  
  ask grid-operators [set hidden? true]
  ask consumers [set hidden? true]
  ask producers [set hidden? true]
  
  ask patches [
    set pcolor white
  ]
  
  ask buses [
    set shape "circle"
    set size 0.5
    set color black
  ]
  
  ask generators [
    set shape "circle"
    set size 1
    set color blue
    set label generator-maximum-real-power-output
    set label-color white
  ]
  
  ask loads [
    set shape "circle"
    set size 1
    set color green
    set label round load-power-received
    set label-color white
  ]
  
  ask bus-links [
    if (link-status = 1) [set color black]
    if (link-status = 0) [set color red]
    set label round link-load
    set label-color black
  ]

end  
@#$#@#$#@
GRAPHICS-WINDOW
390
20
852
503
16
16
13.7
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

SWITCH
46
461
262
494
print-power-flow-data?
print-power-flow-data?
1
1
-1000

BUTTON
129
75
192
108
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
198
76
261
109
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
51
74
124
107
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
861
20
1122
177
consumer satisfaction
NIL
NIL
0.0
10.0
0.0
1.1
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "ifelse (count consumers > 0) [plot mean [consumer-satisfaction] of consumers] [plot 0]"

PLOT
860
184
1121
363
power line flows
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ";plot the power flows\nask bus-links [\n  set-current-plot-pen word [bus-number] of end1 [bus-number] of end2\n  plot link-load\n]"
PENS

SLIDER
49
262
360
295
mean-power-demand-of-consumers
mean-power-demand-of-consumers
0
500
100
10
1
NIL
HORIZONTAL

SWITCH
37
424
376
457
use-default-demand-and-generation-values?
use-default-demand-and-generation-values?
0
1
-1000

PLOT
861
368
1195
521
generation and demand
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"generator output" 1.0 0 -13345367 true "" "plot total-generator-output"
"power consumed" 1.0 0 -2674135 true "" "plot sum [load-power-received] of loads"
"power demanded" 1.0 0 -7500403 true "" "plot sum [consumer-demand] of consumers"

CHOOSER
49
117
215
162
case-to-load
case-to-load
"IEEE case 9" "IEEE case 14" "IEEE case 30" "IEEE case 118" "random network"
2

SLIDER
47
303
366
336
stddev-power-demand-of-consumers
stddev-power-demand-of-consumers
0
500
0
5
1
NIL
HORIZONTAL

SLIDER
60
539
280
572
number-of-substations
number-of-substations
0
25
10
1
1
NIL
HORIZONTAL

SLIDER
61
577
281
610
number-of-loads
number-of-loads
0
25
5
1
1
NIL
HORIZONTAL

SLIDER
62
615
281
648
number-of-generators
number-of-generators
0
25
5
1
1
NIL
HORIZONTAL

SLIDER
62
653
283
686
number-of-redundant-lines
number-of-redundant-lines
0
25
5
1
1
NIL
HORIZONTAL

SLIDER
48
347
283
380
capacity-of-generators
capacity-of-generators
0
500
400
10
1
NIL
HORIZONTAL

SWITCH
420
654
599
687
kill-random-links?
kill-random-links?
1
1
-1000

BUTTON
606
654
720
687
NIL
kill-random-link
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1129
20
1642
363
link load vs. consumer satisfaction
mean link load
mean consumer satisfaction
0.0
1.1
0.0
1.1
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" ""

MONITOR
405
520
486
565
links killed
links-killed-this-tick
17
1
11

MONITOR
492
520
598
565
links overloaded
links-overloaded-this-tick
17
1
11

MONITOR
691
521
831
566
NIL
demand-response?
17
1
11

SWITCH
421
615
858
648
allow-demand-response?
allow-demand-response?
1
1
-1000

SWITCH
423
577
856
610
consumers-invest-in-distributed-generation?
consumers-invest-in-distributed-generation?
1
1
-1000

PLOT
1201
368
1629
520
total capacity of distributed generation
time
total capacity
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [consumer-distributed-generation-capacity] of consumers"

SLIDER
59
181
317
214
probability-of-extreme-event
probability-of-extreme-event
0
100
50
1
1
NIL
HORIZONTAL

SLIDER
725
654
857
687
link-repair-time
link-repair-time
0
10
0
1
1
NIL
HORIZONTAL

PLOT
875
525
1197
699
fraction demand served
NIL
NIL
0.0
10.0
0.0
1.1
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot fraction-demand-served"

MONITOR
603
521
686
566
links failed
count bus-links with [link-status = 0]
17
1
11

PLOT
1202
525
1627
701
links killed, overloaded and failed
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"killed" 1.0 0 -16777216 true "" "plot links-killed-this-tick"
"overloaded" 1.0 0 -13345367 true "" "plot links-overloaded-this-tick"
"status=0" 1.0 0 -2674135 true "" "plot count bus-links with [link-status = 0]"

SWITCH
421
693
619
726
increase-link-capacity?
increase-link-capacity?
1
1
-1000

SWITCH
624
693
858
726
add-backup-generators?
add-backup-generators?
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="NoMeasures" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed</metric>
    <metric>links-failed-due-to-overload</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>sum [consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="DemandResponse" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed</metric>
    <metric>links-failed-due-to-overload</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>sum [consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="DistributedGenInvestments" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed</metric>
    <metric>links-failed-due-to-overload</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>sum [consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="NoMeasures2" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="DemandResponse2" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ReducedRepairTime2" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="NoMeasures3Test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="NoMeasures3" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="DemandResponse3" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="NoMeasures4" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="increase-link-capacity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="add-backup-generators?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="IncreasedCapacity4" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="increase-link-capacity?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="add-backup-generators?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BackupGeneration4" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>count bus-links with [link-status = 0]</metric>
    <metric>links-killed-this-tick</metric>
    <metric>links-overloaded-this-tick</metric>
    <metric>mean [link-load] of bus-links</metric>
    <metric>fraction-demand-served</metric>
    <metric>mean [consumer-satisfaction] of consumers</metric>
    <metric>sum [[load-power-received] of consumer-loads] of consumers</metric>
    <metric>sum [consumer-demand - consumer-distributed-generation-capacity] of consumers</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 1]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 2]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 3]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 4]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 5]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 6]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 7]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 8]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 9]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 10]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 11]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 12]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 13]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 14]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 15]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 16]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 17]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 18]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 19]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 20]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 21]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 22]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 23]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 24]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 25]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 26]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 27]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 28]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 29]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 30]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 31]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 32]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 33]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 34]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 35]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 36]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 37]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 38]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 39]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 40]</metric>
    <metric>[link-load] of one-of bus-links with [link-number = 41]</metric>
    <enumeratedValueSet variable="number-of-loads">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="link-repair-time">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-generators">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-default-demand-and-generation-values?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="increase-link-capacity?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-power-demand-of-consumers">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="case-to-load">
      <value value="&quot;IEEE case 30&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="kill-random-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="consumers-invest-in-distributed-generation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stddev-power-demand-of-consumers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="probability-of-extreme-event">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-redundant-lines">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="add-backup-generators?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow-demand-response?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-power-flow-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-of-generators">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-substations">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
