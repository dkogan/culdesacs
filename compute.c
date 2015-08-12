#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <float.h>
#include <stdbool.h>

#include "binary_heap.h"


typedef int32_t node_index_t;
typedef int32_t neighbor_index_t;

struct node_t
{
    float    lat, lon;
    uint32_t neighborpool_idx;

    // The shortest distance along the road network to this node. If not yet
    // initialized, this is FLT_MAX. If already processed, this is <0
    float dist_graph;

    unsigned idx; // position in the heap structure
};


// The nodes
static struct node_t* node_pool = NULL;

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
    return node_pool[node].dist_graph < 0.0f;
}

static void node_set_visited(node_index_t node)
{
    node_pool[node].dist_graph = -1.0f;
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

static void push_result(node_index_t node)
{
    printf("%f %f %f\n", node_pool[node].lat, node_pool[node].lon, node_pool[node].dist_graph);
}

static void process_node(node_index_t node)
{
    push_result(node);
    node_set_visited(node);

    for(neighbor_index_t neighbor_idx = node_pool[node].neighborpool_idx;
        neighbor_pool[neighbor_idx] >= 0;
        neighbor_idx++)
    {
        node_index_t neighbor = neighbor_pool[neighbor_idx];

        if(!node_visited(neighbor))
        {
            float dist_graph_new_candidate = node_pool[node].dist_graph + dist(neighbor, node);
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
    // lat lon neighbor_pool_idx
    // ...
    // Nneighbor_pool: xxx
    // neighbor_pool[0]
    // neighbor_pool[1]
    // ...

    int N;

    scanf("Nnodes: %d", &N);
    node_pool = malloc(N * sizeof(sizeof(node_pool[0])));
    for(int i=0; i<N; i++)
        scanf("%f %f %d", &node_pool[i].lat, &node_pool[i].lon, &node_pool[i].neighborpool_idx);

    scanf("Nneighbor_pool: %d", &N);
    neighbor_pool = malloc(N * sizeof(sizeof(neighbor_pool[0])));
    for(int i=0; i<N; i++)
        scanf("%d", &neighbor_pool[i]);
}

int main(void)
{
    parse_input();



    heap = binheap_new( node_cmp_callback, node_update_callback);

    push(0);

    while(1)
    {
        node_index_t node = pop();
        if( node < 0 )
            break; // active list empty

        process_node(node);
    }

    return 0;
}
