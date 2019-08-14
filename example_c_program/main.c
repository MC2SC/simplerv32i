
int main();

void
_start(void)
{ 
  main();
}

unsigned int *led = (unsigned int*) 8464; // memory address of led peripheral

unsigned int change_led(unsigned int val){
  
 	*led = val;

	return 0;

}

int main(){

  unsigned int i = 0;
	while(i<10){
		*led = 3;
		change_led(i);
		i++;
	}
	
	return 0;
}
