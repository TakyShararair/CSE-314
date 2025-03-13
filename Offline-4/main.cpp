#include <iostream>
#include <thread>
#include <mutex>
#include <semaphore.h>
#include <unistd.h> // for sleep() function
#include <vector>
#include <chrono> // measuring time interval
#include "poisson_random_generator.h"
#include <ctime>

using namespace std;

// Define semaphores and mutexes
sem_t gallery1;  // POSIX semaphore
sem_t glass_corridor;
mutex step_mutex[3];
mutex standard_lock;
mutex premium_lock;
mutex photo_booth_lock;
mutex access_lock;
mutex print_lock;

int standard_visitor = 0;  // Reader count or standard Visitor Count
int premium_visitor = 0;  // Writer count  or premium Visitor Count
int time_in_hallway;
int time_in_gallery1;
int time_in_gallery2;
int time_in_photo_booth;
int visitor_number_in_gallery1;


timespec start_time;

void initialize_start_time() {
    clock_gettime(CLOCK_MONOTONIC, &start_time);
}

void log_with_timestamp(const string &message, int visitor_id) {
    timespec current_time;
    clock_gettime(CLOCK_MONOTONIC, &current_time);
    string color;
     if(message == "has arrived at A"){
        color = "\033[32m";  
    } else if (message == "has arrived at B") {
        color = "\033[34m";  
    } else if(message == " is at C (entered Gallery 1) ")
    {
       color = "\033[31m";  
    }
    else if(message == "is at D(exiting Gallery 1) ")
    {
       color = "\033[33m";
    }
    else if(message == "is leaving Glass Corridor ")
    {
        color = "\033[33m";
    }
     else if(message == "is at E(entered Gallery 2)")
     {
        color = "\033[35m";
     }
      else if(message == "is at Glass Corridor ")
      {
        color = "\033[36m";
      }
      else if(message == "is about to enter the photo booth")
      {
          color = "\033[91m";
      }
      else if(message == "inside photo booth (Premium)")
      {
        color = "\033[92m";
      }
      else if(message == "inside photo booth (Standard)")
      {
        color = "\033[31m";
      }
     else {
        color = "\033[0m";   // Reset/Default color
    }
    long long elapsed_time = current_time.tv_sec - start_time.tv_sec;
    print_lock.lock();
    cout << color << "Visitor " << visitor_id << " " << message << " at timestamp " << elapsed_time << "\033[0m" << endl;
    print_lock.unlock();
}


void visit_museum(int visitor_id) {
     int random_time = get_random_number();
     int arrival_time = (random_time) % 5 ;
    
    sleep(arrival_time);
    // Step 0: Hallway entry
    log_with_timestamp("has arrived at A", visitor_id);
    sleep(time_in_hallway);
    log_with_timestamp("has arrived at B", visitor_id);  
    sleep(1);
    // Step 1: Moving to Gallery 1
    step_mutex[0].lock();
    log_with_timestamp("is at step 1", visitor_id);  
    sleep(1);    
    step_mutex[1].lock();
    log_with_timestamp("is at step 2", visitor_id);
    
    step_mutex[0].unlock();
    sleep(1);
    // Step 2: Moving to Gallery 1 entry
    step_mutex[2].lock();
    log_with_timestamp("is at step 3", visitor_id);
    
    step_mutex[1].unlock(); 
     sleep(1);
    // Enter Gallery 1 (limit 5 visitors)
    sem_wait(&gallery1);
    log_with_timestamp(" is at C (entered Gallery 1) ", visitor_id);
       
    step_mutex[2].unlock();
    sleep(time_in_gallery1);
    // Glass Corridor (limit 3 visitors)
    sem_wait(&glass_corridor);
    log_with_timestamp("is at D(exiting Gallery 1) ", visitor_id);   
    //sleep(1);
    sem_post(&gallery1);  // Leave Gallery 1
    log_with_timestamp("is at Glass Corridor ", visitor_id);
    sleep(1);
    sem_post(&glass_corridor);  // Leave Glass Corridor
    log_with_timestamp("is leaving Glass Corridor ",visitor_id);
    log_with_timestamp("is at E(entered Gallery 2)", visitor_id);
    
    sleep(time_in_gallery2);

    // Photo booth section (Reader-Writer problem)
    log_with_timestamp("is about to enter the photo booth", visitor_id);

    if (visitor_id >= 2001 && visitor_id <= 2100) {  // Premium ticket holder (Writer)
        // Writer logic
        premium_lock.lock();
        premium_visitor++;
        if (premium_visitor == 1)
        {
            access_lock.lock();
        } 
        premium_lock.unlock();

        photo_booth_lock.lock();
        log_with_timestamp("inside photo booth (Premium)", visitor_id);
    
        sleep(time_in_photo_booth);
        photo_booth_lock.unlock();

        premium_lock.lock();
        premium_visitor--;
        if (premium_visitor == 0)
        {
            access_lock.unlock();
        }
         
        premium_lock.unlock();
    } else {  // Standard ticket holder (Reader)
        // Reader logic
        access_lock.lock();
        standard_lock.lock();
        standard_visitor++;
        if (standard_visitor == 1) {
            photo_booth_lock.lock();
        }
        standard_lock.unlock();
        access_lock.unlock();

        log_with_timestamp("inside photo booth (Standard)", visitor_id);
   
        sleep(time_in_photo_booth);

        standard_lock.lock();
        standard_visitor--;
        if (standard_visitor == 0) {
            photo_booth_lock.unlock();
        }
        standard_lock.unlock();
    }

    log_with_timestamp("has exited the museum", visitor_id);
}

int main(int argc, char* argv[]) {
    if (argc < 6) {
        cout << "Usage: museum_visit N M w x y z" << endl;
        return 1;
    }

    int N = stoi(argv[1]);  // Number of friends (standard ticket holders)
    int M = stoi(argv[2]);  // Number of other visitors (premium ticket holders)
     time_in_hallway = stoi(argv[3]) ;
     time_in_gallery1 = stoi(argv[4]) ;
     time_in_gallery2 = stoi(argv[5]) ;
     time_in_photo_booth = stoi(argv[6]) ;
    // Initialize semaphores
    sem_init(&gallery1, 0, 5);  // Gallery 1 capacity
    sem_init(&glass_corridor, 0, 3);  // Glass Corridor capacity

    vector<thread> visitors;
    initialize_start_time();
    // Create threads for all visitors
    for (int i = 0; i < N; ++i) {
        visitors.emplace_back(visit_museum, 1001 + i);  // Standard ticket holders (ID: 1001-1100)
    }
    for (int i = 0; i < M; ++i) {
        visitors.emplace_back(visit_museum, 2001 + i);  // Premium ticket holders (ID: 2001-2100)
    }

    // Join all threads
    for (auto& visitor : visitors) {
        visitor.join();
    }

    // Destroy semaphores
    sem_destroy(&gallery1);
    sem_destroy(&glass_corridor);

    return 0;
}
