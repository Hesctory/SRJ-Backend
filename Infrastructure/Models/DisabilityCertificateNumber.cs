using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class DisabilityCertificateNumber
{
    public int DisabilityId { get; set; }

    public string? Number { get; set; }

    public virtual Disability Disability { get; set; } = null!;
}
