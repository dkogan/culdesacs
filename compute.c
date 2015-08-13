#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <float.h>
#include <stdbool.h>
#include <math.h>
#include <string.h>

#include "binary_heap.h"


#define die(str) do { fprintf(stderr, str"\n"); exit(1); } while(0)


typedef int32_t node_index_t;
typedef int32_t neighbor_index_t;

#define NOT_YET_IN_HEAP     UINT32_MAX
#define NOT_IN_HEAP_ANYMORE BINHEAP_NOIDX

struct node_t
{
    float    lat, lon;
    uint32_t neighborpool_idx;

    // The shortest distance along the road network to this node. If not yet
    // initialized, this is FLT_MAX
    float dist_graph;

    // position in the heap structure. Could be NOT_YET_IN_HEAP or NOT_IN_HEAP_ANYMORE
    unsigned idx;
};


// The nodes
static struct node_t* node_pool = NULL;

// We start the graph search at this node
static node_index_t node0_idx = -1;

// The neighbor pool describes the neighbors of all of the nodes. For node index
// i, the neighbor indices are in
//
//     neighbor_pool[node_pool[i].neighborpool_idx + 0]
//     neighbor_pool[node_pool[i].neighborpool_idx + 1]
//     ...
//
// Each neighbor list ends with an index <0
static node_index_t* neighbor_pool = NULL;

static bool node_visited(node_index_t node)
{
    return node_pool[node].idx == NOT_IN_HEAP_ANYMORE;
}

static int node_cmp_callback(void* _a, void* _b)
{
    struct node_t* a = (struct node_t*)_a;
    struct node_t* b = (struct node_t*)_b;

    return a->dist_graph < b->dist_graph;
}

static void node_update_callback(void *_a, unsigned newidx)
{
    struct node_t* a = (struct node_t*)_a;

    a->idx = newidx;
}




static struct binheap* heap;

static void push(node_index_t node)
{
    binheap_insert(heap, &node_pool[node]);
}

static node_index_t pop(void)
{
    struct node_t* root = binheap_root(heap);
    if( root == NULL )
        return -1;
    binheap_delete(heap, root->idx);

    return root - &node_pool[0];
}

static void decrease_cost(node_index_t node)
{
    binheap_reorder(heap, node_pool[node].idx);
}

static float distance(node_index_t a, node_index_t b)
{
    float dlat = node_pool[a].lat - node_pool[b].lat;
    float dlon = node_pool[a].lon - node_pool[b].lon;
    return sqrtf( dlat*dlat + dlon*dlon*cosf(node_pool[a].lat)*cosf(node_pool[b].lat));
}

static void push_result(node_index_t node)
{
    printf("%f %f %f %f\n",
           node_pool[node].lat, node_pool[node].lon,
           node_pool[node].dist_graph,
           distance(node0_idx, node));
}

static void process_node(node_index_t node)
{
    push_result(node);

    for(neighbor_index_t neighbor_idx = node_pool[node].neighborpool_idx;
        neighbor_pool[neighbor_idx] >= 0;
        neighbor_idx++)
    {
        node_index_t neighbor = neighbor_pool[neighbor_idx];

        if(!node_visited(neighbor))
        {
            float dist_graph_new_candidate = node_pool[node].dist_graph + distance(neighbor, node);
            if(node_pool[neighbor].dist_graph == FLT_MAX)
            {
                // not yet in heap. Set current route to best found, and add to
                // heap
                node_pool[neighbor].dist_graph = dist_graph_new_candidate;
                push(neighbor);
            }
            else
            {
                // in heap. If this route is better, set it and rejigger the
                // heap
                if( node_pool[neighbor].dist_graph > dist_graph_new_candidate )
                {
                    node_pool[neighbor].dist_graph = dist_graph_new_candidate;
                    decrease_cost(neighbor);
                }
            }
        }
    }
}

static void parse_input(void)
{
    // reads the node_pool and neighbor_pool structures from stdin
    //
    // stdin data has
    //
    // Nnodes: xxx
    // Nneighbors: xxx
    // Node0_idx: xxx
    // lat lon neighbor0 neighbor1 neighbor2 ....
    // ...

    int Nnodes, Nneighbors;

    if( 3 != scanf("Nnodes: %d\nNneighbors: %d\nNode0_idx: %d",
                   &Nnodes, &Nneighbors, &node0_idx))
        die("scanf failed");

    node_pool = malloc(Nnodes * sizeof(node_pool[0]));

    // each node's neighbor list ends with a '-1' neighbor, so I must make room
    // for this extra neighbor
    neighbor_pool = malloc((Nneighbors + Nnodes) * sizeof(neighbor_pool[0]));

    if(node_pool == NULL || neighbor_pool == NULL)
        die("malloc failed");

    static char* lineptr = NULL;
    static size_t line_n = 0;

    int neighborpool_idx = 0;

    for(int i=0; i<Nnodes; i++)
    {
        if( 0 >= getline(&lineptr, &line_n, stdin) )
            die("getline failed");

        if( strcmp(lineptr, "\n") == 0 )
        {
            // blank lines are meaningless. Skip and don't include into Nnodes
            i--;
            continue;
        }


        int bytesread;
        int Ntokens =
            sscanf(lineptr,
                   "%f %f%n",
                   &node_pool[i].lat, &node_pool[i].lon,
                   &bytesread);

        if( Ntokens != 2 && Ntokens != 3 )
            die("sscanf failed");

        node_pool[i].neighborpool_idx = neighborpool_idx;

        node_pool[i].idx        = NOT_YET_IN_HEAP;
        node_pool[i].dist_graph = FLT_MAX;

        while(1)
        {
            int bytesread_here;
            Ntokens = sscanf(&lineptr[bytesread], "%d%n",
                             &neighbor_pool[neighborpool_idx],
                             &bytesread_here);

            if(Ntokens <= 0)
            {
                neighbor_pool[neighborpool_idx++] = -1;
                break;
            }

            neighborpool_idx++;

            bytesread += bytesread_here;
        }
    }

    free(lineptr);
}

int main(void)
{
    parse_input();

    heap = binheap_new( node_cmp_callback, node_update_callback);

    node_pool[node0_idx].dist_graph = 0;
    push(node0_idx);

    while(1)
    {
        node_index_t node = pop();
        if( node < 0 )
            break; // active list empty

        process_node(node);
    }

    return 0;
}
