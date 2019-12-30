<?php

/*
 * Comment
 */
class Planet {
    protected $gravitation;

    public function __construct($gravitation)
    {
        $this->gravitation = $gravitation;
    }

    public function get_gravity_force($mass) {
        // phpmd "else" violation
        if ( !is_null($mass) ) {
            return $mass * $this->gravitation;
        } else {
            return 0;
        }
    }
}

$earh = new Planet(9.81);
if ( is_object($earh) ) {
    echo $earh->get_gravity_force(100);
} else {
    echo "No planet found";
}
