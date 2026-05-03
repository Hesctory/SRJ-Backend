using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Institution
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public string Ruc { get; set; } = null!;

    public int RucStateId { get; set; }

    public virtual RucState RucState { get; set; } = null!;
}
