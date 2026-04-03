<?php

use Inertia\Testing\AssertableInertia as Assert;

test('missing pages are rendered with the inertia errors page', function (): void {
    $response = $this->get('/this-page-does-not-exist');

    $response->assertNotFound();

    $response->assertInertia(fn (Assert $page) => $page
        ->component('Errors')
        ->where('status', 404),
    );
});
